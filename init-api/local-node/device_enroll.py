"""Register a fresh Raspberry; writes private files, never starts a second API.

No invitation/credential in argv, stdout, URL or logs. Enrollment requires an
already issued chief invitation. System package installation is separate.
"""
import argparse
import getpass
import json
import os
from pathlib import Path
import re
import subprocess
import uuid
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler
from urllib.error import HTTPError


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def private_write(path, text):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    if os.name == 'posix':
        descriptor = os.open(Path(path).parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def save_enrollment(data, identity, directory, cloud_origin, role):
    if (data['device_id'] != identity or data['role'] != role or role not in {'primary', 'terminal'} or
            not re.fullmatch(r'[0-9a-z-]+\.gbousecurity\.ru', data['hostname']) or
            not re.fullmatch(r'[a-f0-9]{64}', data['token']) or
            not isinstance(data['school_id'], int) or data['school_id'] < 1):
        raise ValueError('Unexpected enrollment response; no service started')
    if data.get('node_scope') == 'building' and (not isinstance(data.get('building_id'), int) or data['building_id'] < 1):
        raise ValueError('Building-scoped enrollment requires a building')
    if role == 'primary':
        import base64
        import ipaddress
        if (ipaddress.ip_address(data['tunnel_ip']) not in ipaddress.ip_network('10.78.0.0/16') or
                len(base64.b64decode(data['gateway_public_key'], validate=True)) != 32 or
                not re.fullmatch(r'[a-zA-Z0-9.-]+:[0-9]{1,5}', data['gateway_endpoint'])):
            raise ValueError('Unexpected gateway settings')
        config = (f"[Interface]\nPrivateKey = {(directory / 'wireguard.key').read_text().strip()}\n"
                  f"Address = {data['tunnel_ip']}/32\n\n[Peer]\nPublicKey = {data['gateway_public_key']}\n"
                  f"Endpoint = {data['gateway_endpoint']}\nAllowedIPs = 10.77.203.1/32\nPersistentKeepalive = 25\n")
        if not (directory / 'gbou-wg.conf').exists():
            private_write(directory / 'gbou-wg.conf', config)
        elif (directory / 'gbou-wg.conf').read_text() != config:
            raise ValueError('Conflicting existing WireGuard candidate')
    elif (directory / 'gbou-wg.conf').exists():
        raise ValueError('Terminal must not reuse a primary network configuration')
    token = data.pop('token')
    token_path = directory / 'device.token'
    if token_path.exists():
        if token_path.read_text().strip() != token:
            raise ValueError('Enrollment retry returned a different identity')
    else:
        private_write(token_path, token + '\n')
    data['cloud_origin'] = cloud_origin
    document = json.dumps(data, indent=2) + '\n'
    path = directory / 'device.json'
    if path.exists():
        if path.read_text() != document:
            raise ValueError('Conflicting saved enrollment')
    else:
        private_write(path, document)


def main():
    parser = argparse.ArgumentParser(description='Подключить новое устройство без запуска БД')
    parser.add_argument('--cloud', required=True, help='Central HTTPS origin, without /api/v1')
    parser.add_argument('--role', choices=['primary', 'terminal'], required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--directory', type=Path, default=Path('/etc/gbou-device'))
    args = parser.parse_args()
    if os.name != 'posix' or os.geteuid() != 0:
        raise SystemExit('Run as root on the new Raspberry')
    cloud = urlsplit(args.cloud)
    if cloud.scheme != 'https' or not cloud.hostname or cloud.username or cloud.password or cloud.query or cloud.fragment or cloud.path not in {'', '/'}:
        raise SystemExit('Only a trusted HTTPS central origin is allowed')
    directory = args.directory
    if not directory.is_absolute() or directory.is_symlink():
        raise SystemExit('Use an absolute nonsymlink private directory')
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
    if (directory / 'device.json').exists():
        raise SystemExit('Device is already enrolled. Never overwrite existing enrollment')
    identity_path = directory / 'identity'
    if not identity_path.exists():
        private_write(identity_path, str(uuid.uuid4()))
    identity = str(uuid.UUID(identity_path.read_text().strip()))
    public = None
    if args.role == 'primary':
        key_file = directory / 'wireguard.key'
        if not key_file.exists():
            private_write(key_file, subprocess.check_output(['wg', 'genkey'], text=True).strip() + '\n')
        public = subprocess.check_output(['wg', 'pubkey'], input=key_file.read_text(), text=True).strip()
    invitation = getpass.getpass('Одноразовый код подключения (10 минут): ').strip()
    payload = json.dumps({'invitation': invitation, 'device_id': identity,
                          'label': args.label, 'public_key': public}).encode()
    opener = build_opener(NoRedirect(), ProxyHandler({}))
    try:
        with opener.open(Request(cloud.geturl().rstrip('/') + '/api/v1/devices/enroll',
                         data=payload, headers={'Content-Type': 'application/json'}), timeout=30) as response:
            data = json.loads(response.read(32769))
    except HTTPError as error:
        raise SystemExit(f'Enrollment rejected (HTTP{error.code}); no service started')
    save_enrollment(data, identity, directory, cloud.geturl().rstrip('/'), args.role)
    print('Device registered. School URL: https://' + data['hostname'])
    if args.role == 'terminal':
        print('Terminal only: NO database, school sync credential or local API installed.')
        print('Configure existing kiosk GBOU_API_BASE=https://' + data['hostname'] + '/api/v1')
        print('Use an ordinary guard account. Machine enrollment does not authorize school records.')
    else:
        print('Primary is PENDING. API/WireGuard/Caddy not started by this command.')
        print('Prepare isolated database/USB restore, STOP old primary, then activate from chief console.')
        print('Use device.token as GBOU_NODE_TOKEN_FILE only AFTER activation; old sync key will be revoked.')


if __name__ == '__main__':
    main()
