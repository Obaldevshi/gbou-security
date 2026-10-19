"""Update existing gateway PROGRAM only, preserving secrets and topology."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

SOURCE = Path('/root/gbou-release-1.8.0-14')
TARGET = Path('/opt/gbou-gateway')
FILES = ('managed_routes.py', 'reconcile.py')


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError('Gateway program update stopped: ' + args[0])
    return result.stdout.strip()


def main():
    assert os.geteuid() == 0 and SOURCE.is_dir() and TARGET.is_dir()
    assert SOURCE.resolve() == SOURCE and TARGET.resolve() == TARGET
    protected = [Path(p) for p in ('/etc/gbou-gateway/managed.json', '/etc/gbou-gateway/manifest.token',
        '/etc/haproxy/haproxy.cfg', '/etc/wireguard/gbou-wg.conf')]
    def fingerprint(path):
        blob = path.read_bytes()
        if path.name == 'gbou-wg.conf':
            # Existing renderer accumulated empty lines on every timer poll.
            # Preserve every non-empty directive/key/peer, permit whitespace-only
            # canonicalization once, then require stable idempotent rendering.
            blob = b'\n'.join(line.strip() for line in blob.splitlines() if line.strip())
        return hashlib.sha256(blob).hexdigest()
    hashes = {str(p): fingerprint(p) for p in protected}
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path('/var/lib/gbou-gateway/program-before-1.8.0-14-' + stamp)
    backup.mkdir(mode=0o700)
    (backup/'protected-sha256.json').write_text(json.dumps(hashes))
    (backup/'protected-sha256.json').chmod(0o600)
    timer = 'gbou-gateway-reconcile.timer'
    active = subprocess.run(['systemctl','is-active','--quiet',timer]).returncode == 0
    run('systemctl','stop',timer)
    replaced = []
    try:
        for _ in range(30):
            if subprocess.run(['systemctl','is-active','--quiet','gbou-gateway-reconcile.service']).returncode != 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Existing worker still running; no code replaced')
        for name in FILES:
            assert (SOURCE/name).is_file() and not (SOURCE/name).is_symlink()
            assert (TARGET/name).is_file() and not (TARGET/name).is_symlink()
            shutil.copy2(TARGET/name, backup/name)
        state = Path('/var/lib/gbou-gateway/managed-state.json')
        shutil.copy2(state, backup/'managed-state.json')
        for name in FILES:
            shutil.copy2(SOURCE/name, TARGET/(name+'.next'))
            (TARGET/(name+'.next')).chmod(0o644)
            os.replace(TARGET/(name+'.next'), TARGET/name)
            replaced.append(name)
        run('python3', str(TARGET/'reconcile.py'))
        run('python3', str(TARGET/'reconcile.py'), '--apply')
        assert hashes == {str(p): fingerprint(p) for p in protected}
        current = json.loads(state.read_text())
        assert current.get('host_generations')
        print(json.dumps({'gateway_program_updated':True,'network_and_credentials_unchanged':True,
                          'legacy_host_floors_saved':True,'rollback_directory':str(backup)}))
    except BaseException:
        for name in replaced:
            shutil.copy2(backup/name, TARGET/name)
        raise
    finally:
        if active:
            run('systemctl','start',timer)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Gateway release stopped (' + type(error).__name__ + '); inspect protected rollback state') from None
