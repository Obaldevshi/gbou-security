"""Explicit source/media allowlists. Never ships server state or signing credentials."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parents[1]
app = root / 'init-app'
version, build = re.search(r'^version:\s*([^+]+)\+(\d+)', (app / 'pubspec.yaml').read_text(encoding='utf8'), re.M).groups()
tag = f'{version}-{build}'
forbidden = {'.key', '.pem', '.p12', '.pfx', '.mobileprovision', '.jks', '.keystore', '.sqlite', '.sqlite3', '.db', '.token'}

def pack(destination, sources):
    files = sorted(set(path for path in sources if path.is_file()))
    manifest = {}
    with zipfile.ZipFile(destination, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for path in files:
            name = path.relative_to(root).as_posix()
            assert not path.is_symlink() and path.suffix.lower() not in forbidden
            assert not any(part in {'Pods', '.symlinks', 'ephemeral', '.git'} for part in path.parts)
            assert path.name not in {'key.properties', 'local.properties', 'Generated.xcconfig', 'flutter_export_environment.sh'}
            data = path.read_bytes()
            assert b'-----BEGIN PRIVATE KEY-----' not in data and b'-----BEGIN OPENSSH PRIVATE KEY-----' not in data
            if path.name in {'.env', '.env.example'}:
                for line in data.decode('utf8').splitlines():
                    if line.strip() and not line.lstrip().startswith('#'):
                        assert line.split('=', 1)[0] in {'BASE_URL', 'BASE_URL_WEB'}
            output.writestr(name, data)
            manifest[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        output.writestr('GBOU-CANDIDATE-MANIFEST.json', json.dumps({'status': 'INTERNAL_QA_NOT_STORE_APPROVED',
            'version': f'{version}+{build}', 'files': manifest}, ensure_ascii=False, indent=2))
    return {'file': destination.name, 'bytes': destination.stat().st_size,
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(), 'files': len(files)}

documents = [root / 'docs/cross-store-readiness.html', root / 'docs/QA-START-HERE.html',
             root / 'docs/third-party-review.html', root / 'docs/raspberry-second-device.html']
artifacts = [root / 'artifacts/android-release-validation.json', root / 'artifacts/android-bundle-validation.json',
    root / 'artifacts/ios-source-audit.json', root / 'artifacts/license-audit/inventory.json',
    root / 'artifacts/cross-store-qa-results.json', root / f'release/store-candidate-{tag}.json']
apk = root / f'release/gbou-security-{tag}.apk'
aab = root / f'release/gbou-security-{tag}.aab'
assert apk.is_file() and aab.is_file()
assert all(path.is_file() for path in documents + artifacts), 'Required QA evidence is missing'
qa = pack(root / f'release/gbou-security-{tag}-QA-kit.zip', documents + artifacts + [apk, aab]
    + list((root / 'artifacts/visual-audit-cross-store').glob('*.png'))
    + list((root / 'artifacts/visual-audit-store').glob('*.png')))
ios_documents = [path for path in documents if path.name != 'QA-START-HERE.html']
ios_sources = [*ios_documents, root / 'docs/IOS-START-HERE.html', app / 'pubspec.yaml', app / 'pubspec.lock', app / 'l10n.yaml',
    root / 'tools/build_ios_candidate.sh', root / 'tools/prepare_store_privacy.py']
ios_sources += list((app / 'lib').rglob('*')) + list((app / 'assets').rglob('*'))
for name in ('03-student-picker-last-of-35.png', 'stress-360-students-large-text.png',
             'qr-foreign-origin-rejected.png', 'web-login-320.png', 'web-picker-320.png',
             'web-demo-qr-pending.png'):
    ios_sources.append(root / 'artifacts/visual-audit-cross-store' / name)
for path in (app / 'ios').rglob('*'):
    if any(part in {'Pods', '.symlinks', 'ephemeral', 'xcuserdata'} for part in path.parts):
        continue
    if path.name in {'Generated.xcconfig', 'flutter_export_environment.sh', 'GeneratedPluginRegistrant.m', 'GeneratedPluginRegistrant.h'}:
        continue
    ios_sources.append(path)
ios = pack(root / f'release/gbou-security-ios-source-{tag}.zip', ios_sources)
result = {'status': 'INTERNAL_QA_NOT_SUBMITTED', 'version': f'{version}+{build}', 'qa_kit': qa,
          'ios_source_handoff': ios, 'contains_signing_secrets_or_server_database': False,
          'ios_binary_built': False}
(root / 'artifacts/cross-store-package-manifest.json').write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
