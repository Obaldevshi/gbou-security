"""Validate the release artifact without printing or packaging signing secrets."""
from pathlib import Path
import gzip
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get('ANDROID_SDK_ROOT', os.environ.get('ANDROID_HOME',
    str(Path.home() / 'AppData/Local/Android/Sdk')))) / 'build-tools/36.0.0'
version_match = re.search(r'^version:\s*([\w.-]+)\+(\d+)',
                          (ROOT / 'init-app/pubspec.yaml').read_text(), re.M)
version, build = version_match.groups()
apk = ROOT / 'init-app/build/app/outputs/flutter-apk/app-release.apk'
signature = subprocess.run([str(SDK / 'apksigner.bat'), 'verify', '--verbose', '--print-certs', str(apk)],
                           check=True, capture_output=True, text=True).stdout
assert 'CN=GBOU Security' in signature and 'Android Debug' not in signature
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
subprocess.run([str(SDK / 'zipalign.exe'), '-c', '-P', '16', '4', str(apk)], check=True, capture_output=True)
badging = subprocess.check_output([str(SDK / 'aapt.exe'), 'dump', 'badging', str(apk)], text=True, encoding='utf8')
assert "name='ru.obaldevshi.gbou_security'" in badging
assert "versionCode='" + build + "'" in badging and "versionName='" + version + "'" in badging
assert "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
assert 'application-debuggable' not in badging
libraries = []
with zipfile.ZipFile(apk) as archive:
    names = archive.namelist()
    assert not any(name.endswith(('.keystore', '.jks', '/key.properties')) for name in names)
    notices = [name for name in names if name.endswith('/NOTICES.Z')]
    assert len(notices) == 1
    notices_text = gzip.decompress(archive.read(notices[0]))
    assert b'flutter' in notices_text.lower() and b'go_router' in notices_text
    for source in (ROOT / 'init-app/assets/licenses').glob('*.txt'):
        assert archive.read('assets/flutter_assets/assets/licenses/' + source.name) == source.read_bytes()
    for name in names:
        if not name.endswith('.so') or not any(part in name for part in ('/arm64-v8a/', '/x86_64/')):
            continue
        data = archive.read(name)
        assert data[:6] == b'\x7fELF\x02\x01'
        offset = struct.unpack_from('<Q', data, 32)[0]
        size, count = struct.unpack_from('<HH', data, 54)
        aligns = [row[7] for row in (struct.unpack_from('<IIQQQQQQ', data, offset + i * size)
                                    for i in range(count)) if row[0] == 1]
        assert aligns and min(aligns) >= 16384, 'ELF page alignment: ' + name
        libraries.append({'file': name, 'minimum_load_alignment': min(aligns)})
result = {'version': version + '+' + build, 'package': 'ru.obaldevshi.gbou_security',
          'apk_bytes': apk.stat().st_size, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
          'signer_certificate_sha256': re.search(r'certificate SHA-256 digest: (\w+)', signature).group(1),
          'release_signer_not_debug': True, 'signature_v2': True, 'zip_alignment_16kb': True,
          'elf_64bit': libraries, 'license_assets_match_source': True,
          'flutter_aggregate_notices_bytes': len(notices_text), 'min_sdk': 24, 'target_sdk': 36}
destination = ROOT / ('release/gbou-security-' + version + '-' + build + '.apk')
shutil.copy2(apk, destination)
output = ROOT / 'artifacts/android-release-validation.json'
output.write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
