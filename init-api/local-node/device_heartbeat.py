#!/usr/bin/env python3
"""One bounded heartbeat using an existing scoped device key; no school rows."""
import json
import os
from pathlib import Path
import re
from datetime import datetime, timezone
from urllib.request import Request, build_opener, ProxyHandler, HTTPRedirectHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    root = Path('/etc/gbou-device')
    document = root / 'device.json'
    if document.is_symlink() or document.stat().st_mode & 0o077:
        raise ValueError('Unsafe device descriptor')
    data = json.loads(document.read_text())
    if data['cloud_origin'] != 'https://obaldevshi-gbou-security-ac8a.twc1.net':
        raise ValueError('Unexpected central origin')
    path = Path(data.get('token_file', '/etc/gbou-device/device.token'))
    if str(path) not in {'/etc/gbou-device/device.token', '/etc/gbou-local/node.token'} or path.is_symlink() or path.stat().st_mode & 0o077:
        raise ValueError('Unsafe credential file')
    token = path.read_text().strip()
    if not 40 <= len(token) <= 128:
        raise ValueError('Invalid credential')
    if not re.fullmatch(r'[a-z0-9-]+\.gbousecurity\.ru', data['hostname']):
        raise ValueError('Unexpected school address')
    opener = build_opener(ProxyHandler({}), NoRedirect())
    with opener.open(Request(data['cloud_origin'] + '/api/v1/devices/heartbeat', data=b'',
                            headers={'X-School-Device-Token': token}), timeout=20) as response:
        status = json.loads(response.read(32768))
    if (status['device_id'] != data['device_id'] or status['hostname'] != data['hostname']
            or status['role'] != data['role'] or status['state'] != 'active'
            or (data['role'] == 'primary' and not status['is_primary'])):
        raise ValueError('Device no longer owns this role')
    folder = Path('/var/lib/gbou-device')
    folder.mkdir(mode=0o700, exist_ok=True)
    candidate = folder / 'heartbeat.tmp'
    descriptor = os.open(candidate, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(json.dumps({'last_success': datetime.now(timezone.utc).isoformat(), 'generation': status['generation']}) + '\n')
    os.replace(candidate, folder / 'heartbeat.json')
    print('Device heartbeat OK; scoped registration active')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Device heartbeat failed (' + type(error).__name__ + '); no credentials printed')
