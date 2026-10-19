"""Structural/upload-signature check; Play Console validation is still required."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
bundle = root / 'init-app/build/app/outputs/bundle/release/app-release.aab'
version, build = re.search(r'^version:\s*([^+]+)\+(\d+)', (root / 'init-app/pubspec.yaml').read_text(encoding='utf8'), re.M).groups()
jarsigner = shutil.which('jarsigner') or str(Path(os.environ.get('JAVA_HOME', 'C:/Program Files/Android/Android Studio/jbr')) / 'bin/jarsigner.exe')
result = subprocess.run([jarsigner, '-J-Duser.language=en', '-J-Duser.country=US', '-verify', str(bundle)], check=True, capture_output=True, text=True)
assert 'jar verified' in result.stdout.lower(), 'App bundle signature not verified'
keytool = str(Path(jarsigner).with_name('keytool.exe' if os.name == 'nt' else 'keytool'))
certificate = subprocess.check_output([keytool, '-J-Duser.language=en', '-printcert', '-jarfile', str(bundle)], text=True)
fingerprint = re.search(r'SHA256:\s*([A-Fa-f0-9:]+)', certificate).group(1).replace(':', '').lower()
apk_check = json.loads((root / 'artifacts/android-release-validation.json').read_text())
assert apk_check['version'] == f'{version}+{build}'
assert fingerprint == apk_check['signer_certificate_sha256'].lower(), 'Bundle and APK release signers differ'
with zipfile.ZipFile(bundle) as archive:
    names = archive.namelist()
    assert 'BundleConfig.pb' in names and 'base/manifest/AndroidManifest.xml' in names
    assert any(name.startswith('base/dex/') for name in names)
    assert 'base/lib/arm64-v8a/libflutter.so' in names
    assert not any(name.endswith(('.jks', '.keystore', '/key.properties')) for name in names)
output = {'version': f'{version}+{build}', 'bundle_bytes': bundle.stat().st_size,
          'sha256': hashlib.sha256(bundle.read_bytes()).hexdigest(), 'jar_signature_verified': True,
          'signer_matches_release_apk': True,
          'play_console_validation_executed': False, 'store_submission_executed': False}
destination = root / f'release/gbou-security-{version}-{build}.aab'
shutil.copy2(bundle, destination)
(root / 'artifacts/android-bundle-validation.json').write_text(json.dumps(output, indent=2), encoding='utf8')
print(json.dumps(output))
