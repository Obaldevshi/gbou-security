"""Read-only source/SDK inventory. Not a substitute for an Xcode archive validation."""
from pathlib import Path
from urllib.parse import unquote, urlparse
import json
import plistlib
import re
from PIL import Image

root = Path(__file__).resolve().parents[1]
app = root / 'init-app'
info = plistlib.loads((app / 'ios/Runner/Info.plist').read_bytes())
manifest = plistlib.loads((app / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
project = (app / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
assert info['CFBundleDisplayName'] == 'GBOU Security'
assert info['NSCameraUsageDescription'] and info['NSLocalNetworkUsageDescription']
assert not info.get('NSAppTransportSecurity', {}).get('NSAllowsArbitraryLoads', False)
assert not any(key in info for key in ('NSMicrophoneUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSFaceIDUsageDescription'))
assert 'PrivacyInfo.xcprivacy in Resources' in project
assert manifest['NSPrivacyTracking'] is False
assert all(row['NSPrivacyCollectedDataTypePurposes'] for row in manifest['NSPrivacyCollectedDataTypes'])
config = json.loads((app / '.dart_tool/package_config.json').read_text())
graph = json.loads((app / '.dart_tool/package_graph.json').read_text())
packages = {row['name']: row for row in graph['packages']}
runtime, todo = set(), list(packages['mobile_template']['dependencies'])
while todo:
    name = todo.pop()
    if name in runtime:
        continue
    runtime.add(name)
    todo.extend(packages.get(name, {}).get('dependencies', []))
plugins = json.loads((app / '.flutter-plugins-dependencies').read_text())['plugins'].get('ios', [])
inventory = []
for row in plugins:
    if row['name'] not in runtime:
        continue
    folder = Path(row['path'])
    manifests = list(folder.glob('ios/**/PrivacyInfo.xcprivacy')) + list(folder.glob('darwin/**/PrivacyInfo.xcprivacy'))
    for path in manifests:
        plistlib.loads(path.read_bytes())
    inventory.append({'package': row['name'], 'privacy_manifests_present': len(manifests),
                      'manifests_parse': True,
                      'archive_inclusion_verified': False})
icons = []
for path in (app / 'ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'):
    with Image.open(path) as image:
        icons.append({'file': path.name, 'size': image.size,
                      'has_nonopaque_pixels': 'A' in image.getbands() and image.getchannel('A').getextrema()[0] < 255})
assert any(row['size'] == (1024, 1024) for row in icons)
result = {'source_checks_passed': True, 'platform': 'Windows', 'xcode_build_executed': False,
          'simulator_or_physical_iphone_tested': False, 'sdk_plugins': inventory, 'icons': icons,
          'bundle_identifiers': sorted(set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', project))),
          'pending': ['owned_Apple_team_and_bundle_registration', 'macOS_Xcode26_or_later_iOS26SDK_or_later',
                      'pod_install_and_archive_aggregate_privacy_report', 'signatures_of_listed_binary_SDKs',
                      'iPhone_iPad_camera_denial_background_keyboard_secure_storage_tests',
                      'export_compliance_owner_answers', 'policy_approval_and_App_Privacy_form',
                      'reviewer_full_access_arrangement']}
(root / 'artifacts/ios-source-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
print(json.dumps({'source_checks_passed': True, 'runtime_ios_plugins': len(inventory),
                  'plugins_without_local_manifest': [row['package'] for row in inventory if not row['privacy_manifests_present']],
                  'xcode_build_executed': False, 'nonopaque_icons': sum(row['has_nonopaque_pixels'] for row in icons)}))
