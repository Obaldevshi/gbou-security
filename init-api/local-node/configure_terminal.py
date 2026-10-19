"""Connect an ALREADY INSTALLED kiosk to the enrolled school's stable HTTPS URL.

No database replication, cloud fallback, credentials in logs or new software.
Invoked deliberately on a child Pi after device_enroll.py --role terminal.
"""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run as root on the CHILD terminal, not the school server')
    root = Path('/etc/gbou-device')
    data = json.loads((root / 'device.json').read_text())
    assert data['role'] == 'terminal'
    assert re.fullmatch(r'[a-z0-9-]+\.gbousecurity\.ru', data['hostname'])
    if subprocess.run(['systemctl', 'is-active', '--quiet', 'gbou-local-api']).returncode == 0:
        raise SystemExit('Refusing: a school API is active on this Pi. Never demote it automatically')
    if Path('/var/lib/gbou-local/school.sqlite3').exists():
        raise SystemExit('Refusing: school database found; inspect it before configuring a child')
    for secret in [root / 'device.token', root / 'device.json']:
        assert not secret.is_symlink() and secret.stat().st_mode & 0o077 == 0
    opener = build_opener(NoRedirect(), ProxyHandler({}))
    token = (root / 'device.token').read_text().strip()
    with opener.open(Request(data['cloud_origin'] + '/api/v1/devices/heartbeat', data=b'',
                             headers={'X-School-Device-Token': token}), timeout=20) as response:
        status = json.load(response)
    assert status['device_id'] == data['device_id'] and status['state'] == 'active'
    assert status['hostname'] == data['hostname'] and status['role'] == 'terminal'
    if data.get('node_scope') == 'building':
        assert status.get('school_id') == data['school_id'] and status.get('building_id') == data['building_id']
    with opener.open('https://' + data['hostname'] + '/ready', timeout=20) as response:
        assert response.status == 200
    target = Path('/etc/gbou-kiosk.conf')
    assert target.is_file() and not target.is_symlink(), 'Install the existing kiosk package first'
    original = target.read_text()
    # Preserve Wi-Fi/UI settings; never write the machine token into browser config.
    lines = [line for line in original.splitlines() if not line.startswith(('GBOU_API_BASE=', 'GBOU_KIOSK_LOCAL_MODE='))]
    lines += ['GBOU_API_BASE=https://' + data['hostname'] + '/api/v1', 'GBOU_KIOSK_LOCAL_MODE=0']
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = target.with_name('gbou-kiosk.conf.before-terminal-' + stamp)
    shutil.copyfile(target, backup)
    backup.chmod(0o600)
    candidate = target.with_name('gbou-kiosk.conf.terminal-candidate')
    with candidate.open('x') as stream:
        candidate.chmod(0o600)
        stream.write('\n'.join(lines) + '\n')
    os.replace(candidate, target)
    try:
        subprocess.run(['systemctl', 'restart', 'gbou-kiosk'], check=True)
        subprocess.run(['systemctl', 'is-active', '--quiet', 'gbou-kiosk'], check=True)
    except BaseException:
        shutil.copyfile(backup, target)
        target.chmod(0o600)
        subprocess.run(['systemctl', 'restart', 'gbou-kiosk'], check=False)
        raise
    print('Child kiosk connected to https://' + data['hostname'] + '; sign in as guard. No school database installed.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Child configuration failed (' + type(error).__name__ + '); private details omitted')
