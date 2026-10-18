"""Install reviewed local-only login protection, retaining exact rollback files."""
import hashlib
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
from datetime import datetime, timezone
import urllib.request
import urllib.error


def main():
    assert os.geteuid() == 0
    root = Path('/opt/gbou-local-api')
    expected = {
        'app/services/auth_service.py': '726fada7a84f8beca856140a6675ab6a864af8e6ce78b1ae24919930f1be604b',
        'app/core/security.py': '0600f841fe48c0089959d308f4ce6af92c253c0aac556799fba1b6554be72473',
        'app/main.py': '12dd45337d35a199661cf247faa0b3618946b22095d91ef3284d11d999a41a23',
    }
    for name, digest in expected.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f'Unexpected source: {name}'
    guard = root / 'app/services/login_attempt_guard.py'
    assert not guard.exists(), 'Protection is already installed; do not overwrite'
    backup = root / f'rollback-login-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}'
    backup.mkdir(mode=0o700)
    for name in expected:
        target = backup / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target)
    replacements = {
        'app/services/auth_service.py': Path('/tmp/gbou-auth_service.py'),
        'app/core/security.py': Path('/tmp/gbou-security.py'),
        'app/services/login_attempt_guard.py': Path('/tmp/gbou-login_attempt_guard.py'),
    }
    try:
        for name, source in replacements.items():
            shutil.copyfile(source, root / name)
            os.chmod(root / name, 0o644)
        main_file = root / 'app/main.py'
        content = main_file.read_text()
        needle = '        status_code=exc.status_code,\n'
        assert content.count(needle) == 1
        main_file.write_text(content.replace(needle, needle + '        headers=exc.headers,\n'))
        for name in (*replacements, 'app/main.py'):
            py_compile.compile(str(root / name), doraise=True)
        subprocess.run(['systemctl', 'restart', 'gbou-local-api'], check=True, timeout=30)
    except Exception:
        for name in expected:
            shutil.copy2(backup / name, root / name)
        if guard.exists():
            guard.unlink()
        subprocess.run(['systemctl', 'restart', 'gbou-local-api'], timeout=30)
        raise
    print(json.dumps({'login_protection_installed': True, 'rollback': str(backup),
                      'cloud_configuration_unchanged': True}))


if __name__ == '__main__':
    main()
