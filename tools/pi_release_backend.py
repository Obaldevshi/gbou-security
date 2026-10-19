"""Explicit existing-Pi update: encrypted USB restore, additive SQL, code-only rollback.

No install.sh, dependency upgrades, settings, Wi-Fi, keys, writer or DB replacement.
Run --stage first, then --apply only after the offline-copy probe succeeds.
"""
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen
import zipfile

from pi_release_probe import DB, fingerprints, migrate

ROOT = Path('/opt/gbou-local-api')
STAGE = Path('/opt/gbou-release-1.7.0-12')
TIMERS = ('gbou-local-sync.timer', 'gbou-local-backup.timer', 'gbou-device-heartbeat.timer')
JOBS = ('gbou-local-sync.service', 'gbou-local-backup.service', 'gbou-device-heartbeat.service')


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise RuntimeError('Release command failed: ' + args[0])
    return result.stdout.strip()


def ready():
    for _ in range(30):
        try:
            with urlopen('http://127.0.0.1:8081/ready', timeout=3) as response:
                if response.status == 200:
                    return
        except Exception:
            pass
        time.sleep(1)
    raise RuntimeError('API readiness failed')


def stage(archive, expected):
    assert not STAGE.exists() and archive.is_absolute() and not archive.is_symlink()
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected
    with zipfile.ZipFile(archive) as bundle:
        manifest = json.loads(bundle.read('MANIFEST.json'))
        assert len(manifest) < 300 and set(bundle.namelist()) == set(manifest) | {'MANIFEST.json'}
        assert len(bundle.infolist()) == len(manifest) + 1
        assert sum(p.file_size for p in bundle.infolist()) < 10 * 1024 * 1024
        for name, digest in manifest.items():
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in name
            assert path.parts[0] in {'app', 'scripts'} and path.suffix == '.py'
            assert not stat.S_ISLNK(bundle.getinfo(name).external_attr >> 16)
            assert hashlib.sha256(bundle.read(name)).hexdigest() == digest
        STAGE.mkdir(mode=0o755)
        for name in manifest:
            path = STAGE / name
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            with path.open('xb') as target:
                target.write(bundle.read(name))
            path.chmod(0o644)
    print(json.dumps({'stage_verified': True, 'files': len(manifest), 'database_changed': False}))


def apply():
    assert ROOT.is_dir() and not ROOT.is_symlink() and STAGE.is_dir()
    assert DB.is_file() and not DB.is_symlink()
    assert run('timedatectl', 'show', '-p', 'NTPSynchronized', '--value') == 'yes'
    assert shutil.disk_usage(ROOT).free > 500 * 1024 * 1024
    mount = Path('/mnt/gbou-backup')
    assert mount.is_mount() and mount.stat().st_dev != DB.stat().st_dev
    from dotenv import load_dotenv
    load_dotenv('/etc/gbou-local/api.env', override=True)
    assert os.environ['DEPLOYMENT_MODE'] == 'local'
    assert os.environ['DATABASE_URL'] == 'sqlite:////var/lib/gbou-local/school.sqlite3'
    # Require successful source+real-schema offline role tests before any pause.
    run(str(ROOT / '.venv/bin/python'), '/tmp/pi_release_probe.py', '--copy', '--program', str(STAGE))
    active = [unit for unit in TIMERS if subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode == 0]
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    rollback = Path('/opt/gbou-api-before-1.7.0-12-' + stamp)
    report = Path('/var/lib/gbou-local/release-1.7.0-12-' + stamp + '.json')
    stopped = False
    swapped = []
    verified_backup = None
    identity = (DB.stat().st_dev, DB.stat().st_ino)
    try:
        run('systemctl', 'stop', *active)
        for unit in JOBS:
            # oneshot jobs may already be inactive; stop also prevents in-flight sync.
            run('systemctl', 'stop', unit)
        run('systemctl', 'stop', 'gbou-local-api.service')
        stopped = True
        before = fingerprints(DB)
        sys.path.insert(0, str(ROOT))
        from scripts.local_node import _decrypt_file
        archives = set(mount.glob('school-*.gbou'))
        run('runuser', '-u', 'gbou-local', '--', str(ROOT / '.venv/bin/python'),
            '-m', 'scripts.local_node', 'backup-usb')
        created = set(mount.glob('school-*.gbou')) - archives
        assert len(created) == 1
        verified_backup = created.pop()
        secret = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
        with tempfile.TemporaryDirectory(prefix='release-usb-restore-', dir=DB.parent) as temporary:
            recovery = Path(temporary) / 'recovered.sqlite3'
            _decrypt_file(verified_backup, recovery, secret)
            assert fingerprints(recovery) == before
        # Additive migration only. No import, drop, delete or DB-file rename.
        migrate(DB)
        assert fingerprints(DB) == before
        assert (DB.stat().st_dev, DB.stat().st_ino) == identity
        rollback.mkdir(mode=0o755)
        for directory in ('app', 'scripts'):
            os.rename(ROOT / directory, rollback / directory)
            swapped.append(directory)
            os.rename(STAGE / directory, ROOT / directory)
        run('systemctl', 'start', 'gbou-local-api.service')
        ready()
        result = {'state': 'backend_updated', 'release': '1.7.0+12',
                  'usb_backup': verified_backup.name, 'usb_restore_verified': True,
                  'all_existing_fields_preserved': True, 'sqlite_inode_unchanged': True,
                  'tables': {t: r['rows'] for t, r in before.items()},
                  'rollback_program_directory': str(rollback),
                  'database_replaced': False, 'retention_enabled': False}
        with report.open('x') as output:
            os.chmod(report, 0o600)
            json.dump(result, output)
        print(json.dumps(result))
    except BaseException:
        if swapped:
            run('systemctl', 'stop', 'gbou-local-api.service')
            for directory in reversed(swapped):
                if (ROOT / directory).exists():
                    os.rename(ROOT / directory, rollback / (directory + '-candidate'))
                os.rename(rollback / directory, ROOT / directory)
        # Keep the harmless nullable column; never roll a live DB back over new data.
        if stopped:
            run('systemctl', 'start', 'gbou-local-api.service')
        raise
    finally:
        if active:
            run('systemctl', 'start', *active)


def main():
    assert os.geteuid() == 0
    os.chdir(ROOT)
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--sha256')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    assert bool(args.stage) != args.apply
    if args.stage:
        stage(args.stage, args.sha256)
    else:
        apply()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'release_failed': type(error).__name__, 'inspect_before_retry': True}), file=sys.stderr)
        raise SystemExit(1)
