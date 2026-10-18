"""Install approved gateway files without starting/changing live networking.

Copy this directory to /opt/gbou-gateway first. Run as root once. The dedicated
manifest credential never leaves this machine; only its SHA256 is printed.
"""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess


def create_private(path, content):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())


def main():
    if os.geteuid() != 0:
        raise SystemExit('Root is required on the gateway')
    source = Path(__file__).resolve().parent
    if source != Path('/opt/gbou-gateway'):
        raise SystemExit('Copy the reviewed worker into /opt/gbou-gateway first')
    folder = Path('/etc/gbou-gateway')
    folder.mkdir(mode=0o700, exist_ok=True)
    state = Path('/var/lib/gbou-gateway')
    state.mkdir(mode=0o700, exist_ok=True)
    key = folder / 'manifest.token'
    if not key.exists():
        create_private(key, secrets.token_urlsafe(48) + '\n')
    if key.is_symlink() or key.stat().st_mode & 0o077:
        raise SystemExit('Credential permissions are not private')
    settings = folder / 'managed.json'
    if not settings.exists():
        create_private(settings, json.dumps({
            'manifest_url': 'https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1/devices/gateway-manifest',
            'token_file': str(key),
            'apply_approved': False,
            'preserved_routes': [{
                'hostname': 'school-2036.gbousecurity.ru',
                'tunnel_ip': '10.77.203.2',
            }],
        }, indent=2) + '\n')
    for name in ('gbou-gateway-reconcile.service', 'gbou-gateway-reconcile.timer'):
        target = Path('/etc/systemd/system') / name
        if target.exists() and target.read_bytes() != (source / name).read_bytes():
            raise SystemExit('Existing systemd unit differs; review before replacing')
        shutil.copyfile(source / name, target)
        target.chmod(0o644)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    print('Worker installed; timer NOT enabled; live HAProxy/WireGuard untouched')
    print('GATEWAY_MANIFEST_TOKEN_HASH=' + hashlib.sha256(key.read_text().strip().encode()).hexdigest())


if __name__ == '__main__':
    main()
