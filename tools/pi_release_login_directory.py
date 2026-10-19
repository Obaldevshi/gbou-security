"""Existing-node L14 code/env update, no database migration/import or identity change."""
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import sqlite3
import sys
import tempfile

import pi_release_backend as common

TAG = '1.7.1-13'
ROOT = Path('/opt/gbou-local-api')
DB = Path('/var/lib/gbou-local/school.sqlite3')
ENV = Path('/etc/gbou-local/api.env')
STAGE = Path('/opt/gbou-release-' + TAG)


def fingerprints(path):
    result = {}
    with closing(sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True)) as db:
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert db.execute('PRAGMA foreign_key_check').fetchone() is None
        tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
        for table in tables:
            assert table.replace('_', '').isalnum()
            if table == 'local_meta':
                continue  # operational backup/sync timestamps, not school records
            columns = [row[1] for row in db.execute('PRAGMA table_info("' + table + '")')]
            rows = sorted(json.dumps(tuple(row), ensure_ascii=False, default=str) for row in db.execute(
                'SELECT ' + ','.join('"' + c + '"' for c in columns) + ' FROM "' + table + '"'))
            result[table] = {'rows': len(rows), 'sha256': hashlib.sha256('\n'.join(rows).encode()).hexdigest()}
    return result


def identity():
    return [hashlib.sha256(p.read_bytes()).hexdigest() for p in (
        Path('/etc/gbou-device/device.json'), Path('/etc/gbou-device/device.token'),
        Path('/etc/gbou-local/node.token'), Path('/etc/wireguard/gbou-wg.conf'))]


def apply():
    assert STAGE.is_dir() and not ROOT.is_symlink() and DB.is_file() and not DB.is_symlink()
    assert ENV.stat().st_mode & 0o077 == 0
    from dotenv import load_dotenv
    load_dotenv(ENV, override=True)
    assert os.environ['DEPLOYMENT_MODE'] == 'local'
    assert os.environ['DATABASE_URL'] == 'sqlite:////var/lib/gbou-local/school.sqlite3'
    assert os.environ.get('GBOU_SCHOOL_ID') == '2'
    assert not os.environ.get('LOGIN_DIRECTORY_PEPPER')
    assert Path('/mnt/gbou-backup').is_mount()
    assert DB.stat().st_dev != Path('/mnt/gbou-backup').stat().st_dev
    common.run(str(ROOT / '.venv/bin/python'), '/tmp/pi_release_probe.py', '--copy', '--program', str(STAGE))
    old_identity = identity()
    inode = (DB.stat().st_dev, DB.stat().st_ino)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    rollback = Path('/opt/gbou-api-before-' + TAG + '-' + stamp)
    rollback.mkdir(mode=0o700)
    original_env = ENV.read_bytes()
    (rollback / 'api.env').write_bytes(original_env)
    (rollback / 'api.env').chmod(0o600)
    active = [u for u in common.TIMERS if __import__('subprocess').run(['systemctl', 'is-active', '--quiet', u]).returncode == 0]
    swapped = []
    stopped = False
    try:
        common.run('systemctl', 'stop', *active)
        for unit in common.JOBS:
            common.run('systemctl', 'stop', unit)
        common.run('systemctl', 'stop', 'gbou-local-api.service')
        stopped = True
        before = fingerprints(DB)
        archives = set(Path('/mnt/gbou-backup').glob('school-*.gbou'))
        common.run('runuser', '-u', 'gbou-local', '--', str(ROOT / '.venv/bin/python'),
                   '-m', 'scripts.local_node', 'backup-usb')
        created = set(Path('/mnt/gbou-backup').glob('school-*.gbou')) - archives
        assert len(created) == 1
        backup = created.pop()
        sys.path.insert(0, str(ROOT))
        from scripts.local_node import _decrypt_file
        secret = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
        with tempfile.TemporaryDirectory(prefix='l14-usb-restore-', dir=DB.parent) as folder:
            recovered = Path(folder) / 'recovered.sqlite3'
            _decrypt_file(backup, recovered, secret)
            assert fingerprints(recovered) == before
        assert fingerprints(DB) == before
        for folder in ('app', 'scripts'):
            os.rename(ROOT / folder, rollback / folder)
            swapped.append(folder)
            os.rename(STAGE / folder, ROOT / folder)
        # Mechanical, single-variable update: preserve every other env/key byte.
        lines = original_env.decode().splitlines()
        lines = [line for line in lines if not line.startswith('LOGIN_DIRECTORY_ENABLED=')]
        updated = ('\n'.join(lines) + '\nLOGIN_DIRECTORY_ENABLED=true\n').encode()
        with ENV.open('wb') as stream:
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        assert identity() == old_identity
        assert (DB.stat().st_dev, DB.stat().st_ino) == inode
        assert fingerprints(DB) == before
        common.run('systemctl', 'start', 'gbou-local-api.service')
        common.ready()
        result = {'release': '1.7.1+13', 'backend_updated': True, 'encrypted_usb_backup': backup.name,
                  'usb_restore_verified': True, 'all_school_fields_preserved': True,
                  'sqlite_inode_unchanged': True, 'identity_and_network_keys_unchanged': True,
                  'data_tables': {key: value['rows'] for key, value in before.items()},
                  'rollback_directory': str(rollback), 'database_migrated_or_replaced': False}
        output = DB.parent / ('release-' + TAG + '-' + stamp + '.json')
        with output.open('x') as stream:
            os.chmod(output, 0o600)
            json.dump(result, stream)
        print(json.dumps(result))
    except BaseException:
        if swapped:
            common.run('systemctl', 'stop', 'gbou-local-api.service')
            for folder in reversed(swapped):
                if (ROOT / folder).exists():
                    os.rename(ROOT / folder, rollback / (folder + '-candidate'))
                os.rename(rollback / folder, ROOT / folder)
        ENV.write_bytes(original_env)
        if stopped:
            common.run('systemctl', 'start', 'gbou-local-api.service')
        raise
    finally:
        if active:
            common.run('systemctl', 'start', *active)


def main():
    assert os.geteuid() == 0
    os.chdir(ROOT)
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--sha256')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    assert bool(args.stage) != args.apply
    common.STAGE = STAGE
    if args.stage:
        common.stage(args.stage, args.sha256)
    else:
        apply()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('L14 release failed (' + type(error).__name__ + '); inspect before retry') from None
