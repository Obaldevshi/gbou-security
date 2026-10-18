"""Create the FIRST local release signer. Refuse to replace any existing key.

No credentials in argv, logs, Git, APK or public handoff archive. Run locally.
"""
from pathlib import Path
import csv
import json
import os
import secrets
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'init-app/android'


def main():
    target = ANDROID / 'gbou-security-release.keystore'
    properties = ANDROID / 'key.properties'
    if properties.exists() or target.exists():
        raise SystemExit('A signing configuration/key already exists; refusing to replace it.')
    keytool = Path('C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe')
    if not keytool.is_file():
        raise SystemExit('Android Studio bundled keytool not found')
    for path in (target, properties):
        ignored = subprocess.run(['git', 'check-ignore', '--quiet', str(path)], cwd=ROOT)
        if ignored.returncode != 0:
            raise SystemExit('Signing destination must be ignored by Git first')
    password = secrets.token_hex(32)
    environment = dict(os.environ, GBOU_APP_SIGN_STORE_PASS=password, GBOU_APP_SIGN_KEY_PASS=password)
    subprocess.run([str(keytool), '-genkeypair', '-noprompt', '-alias', 'gbou-security',
                    '-keyalg', 'RSA', '-keysize', '3072', '-sigalg', 'SHA256withRSA',
                    '-validity', '36500', '-dname', 'CN=GBOU Security, OU=Android app signing',
                    '-storetype', 'PKCS12', '-keystore', str(target),
                    '-storepass:env', 'GBOU_APP_SIGN_STORE_PASS', '-keypass:env', 'GBOU_APP_SIGN_KEY_PASS'],
                   env=environment, check=True, capture_output=True)
    with properties.open('x', encoding='utf8', newline='\n') as stream:
        stream.write('storeFile=' + target.as_posix() + '\nstorePassword=' + password
                     + '\nkeyAlias=gbou-security\nkeyPassword=' + password + '\n')
    identity = subprocess.check_output(['whoami', '/user', '/fo', 'csv', '/nh'], text=True)
    sid = next(csv.reader(identity.splitlines()))[1]
    for path in (target, properties):
        subprocess.run(['icacls', str(path), '/inheritance:r', '/grant:r', '*' + sid + ':F', '*S-1-5-18:F'],
                       check=True, capture_output=True)
    print(json.dumps({'state': 'release_signer_created', 'key': target.name,
                      'configuration': 'android/key.properties', 'git_ignored': True,
                      'backup_required': True}))


if __name__ == '__main__':
    main()
