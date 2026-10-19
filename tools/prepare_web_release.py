"""Snapshot an already compiled web release. No rebuilds or secret discovery."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

root = Path(__file__).resolve().parents[1]
mode = sys.argv[1]
assert mode in {'school', 'central'}
version = re.search(r'^version:\s*([^\s]+)', (root / 'init-app/pubspec.yaml').read_text(), re.M)[1]
source = root / 'init-app/build/web'
target = root / ('release/' + mode + '-web-' + version.replace('+', '-'))
assert source.is_dir() and not target.exists()
assert json.loads((source / 'version.json').read_text())['version'] == version.split('+')[0]
# Bootstrap version must agree with compiled code and compressed cache namespace.
(source / 'index.html').write_text((root / 'init-app/web/index.html').read_text(encoding='utf-8')
    .replace('$FLUTTER_BASE_HREF', '/'), encoding='utf-8', newline='\n')
target.mkdir()
count = size = 0
for path in source.rglob('*'):
    if not path.is_file() or path.suffix == '.apk':
        continue
    assert not path.is_symlink()
    relative = path.relative_to(source)
    assert not str(relative).endswith(('.sqlite', '.sqlite3', '.db', '.token', '.key', '.keystore', '.jks', '.properties'))
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    data = path.read_bytes()
    assert b'-----BEGIN PRIVATE KEY-----' not in data
    # These documents traverse Git's text normalization. Never normalize JS/fonts.
    if path.suffix == '.html':
        data = data.replace(b'\r\n', b'\n')
    destination.write_bytes(data)
    count += 1
    size += len(data)
print(json.dumps({'mode': mode, 'version': version, 'files': count, 'bytes': size,
                  'main_js_sha256': hashlib.sha256((target / 'main.dart.js').read_bytes()).hexdigest()}))
