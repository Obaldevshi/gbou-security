"""Create a private operator env upload once. Never emit the pepper."""
from pathlib import Path
import os
import secrets
import subprocess

folder = Path.home() / '.ssh' / 'gbou-local-recovery'
assert folder.is_dir() and not folder.is_symlink()
target = folder / 'login-directory.env'
if target.exists():
    text = target.read_text(encoding='utf-8')
    assert text.startswith('LOGIN_DIRECTORY_ENABLED=true\nLOGIN_DIRECTORY_PEPPER=')
    assert len(text.split('LOGIN_DIRECTORY_PEPPER=', 1)[1].strip()) >= 43
    print('Existing private directory-secret upload retained; no rotation')
else:
    with target.open('x', encoding='utf-8') as stream:
        if os.name == 'nt':
            identity = subprocess.check_output(['whoami'], text=True).strip()
            subprocess.run(['icacls', str(target), '/inheritance:r', '/grant:r',
                            identity + ':F', '*S-1-5-18:F'], check=True, capture_output=True)
        else:
            target.chmod(0o600)
        stream.write('LOGIN_DIRECTORY_ENABLED=true\nLOGIN_DIRECTORY_PEPPER=' + secrets.token_urlsafe(48) + '\n')
    print('Private directory-secret upload created; value omitted')
