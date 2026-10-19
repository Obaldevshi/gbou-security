"""Read-only release inventory; no credential values or personal rows emitted."""
import argparse
import json
from pathlib import Path
import re
import sqlite3
import subprocess


def service(unit):
    return subprocess.run(['systemctl', 'is-active', unit], capture_output=True, text=True).stdout.strip()


def gateway():
    state = json.loads(Path('/var/lib/gbou-gateway/managed-state.json').read_text())
    config = json.loads(Path('/etc/gbou-gateway/managed.json').read_text())
    haproxy = Path('/etc/haproxy/haproxy.cfg').read_text()
    options = []
    path = Path('/root/.ssh/authorized_keys')
    if path.exists():
        for line in path.read_text().splitlines():
            if 'ssh-ed25519 ' in line:
                options.append(line.split('ssh-ed25519 ', 1)[0].strip() or '(unrestricted key options)')
    return {'role': 'gateway', 'services': {u: service(u) for u in (
        'haproxy', 'wg-quick@gbou-wg', 'gbou-gateway-reconcile.timer')},
        'upstreams': sorted(set(re.findall(r'(10\.(?:77|78)\.\d+\.\d+):443', haproxy))),
        'generations': state.get('generations', {}), 'host_floors_present': bool(state.get('host_generations')),
        'preserved_routes': [{k: row.get(k) for k in ('school_id', 'hostname', 'managed_only')}
                             for row in config.get('preserved_routes', [])],
        'apply_approved': config.get('apply_approved') is True,
        'ssh_key_options': options}


def pi():
    data = json.loads(Path('/etc/gbou-device/device.json').read_text())
    db_path = Path('/var/lib/gbou-local/school.sqlite3')
    with sqlite3.connect('file:' + str(db_path) + '?mode=ro', uri=True) as db:
        tables = {t: db.execute('SELECT COUNT(*) FROM ' + t).fetchone()[0]
                  for t in ('schools', 'school_buildings', 'users', 'school_classes', 'students', 'exit_requests')}
        scopes = db.execute('SELECT id,school_id FROM school_buildings ORDER BY id').fetchall()
        integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
        fk_ok = db.execute('PRAGMA foreign_key_check').fetchone() is None
    mount = Path('/mnt/gbou-backup')
    return {'role': 'pi', 'scope': {key: data.get(key) for key in ('school_id','building_id','role','hostname','state')},
        'services': {u: service(u) for u in ('gbou-local-api', 'gbou-kiosk', 'caddy', 'wg-quick@gbou-wg',
            'gbou-local-sync.timer', 'gbou-local-backup.timer', 'gbou-device-heartbeat.timer')},
        'rows': tables, 'building_scopes': scopes, 'integrity': integrity, 'fk_ok': fk_ok,
        'sqlite_inode': db_path.stat().st_ino,
        'separate_usb': mount.is_mount() and mount.stat().st_dev != db_path.stat().st_dev,
        'rebind_in_progress': Path('/var/lib/gbou-reprovision/in-progress').exists()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('target', choices=['gateway','pi'])
    args = parser.parse_args()
    print(json.dumps(gateway() if args.target == 'gateway' else pi()))
