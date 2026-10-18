"""Pack already built static files with hashes; never includes a database/key."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

source = Path(sys.argv[1]).resolve()
destination = Path(sys.argv[2]).resolve()
assert source.is_dir() and (source / 'main.dart.js').is_file()
version = json.loads((source / 'version.json').read_text())
assert version['version'] == '1.6.1' and version['build_number'] == '11'
files = sorted(path for path in source.rglob('*') if path.is_file())
assert 50 < len(files) < 256
manifest = {}
for path in files:
    name = path.relative_to(source).as_posix()
    assert not path.is_symlink()
    assert not name.endswith(('.sqlite', '.sqlite3', '.db', '.token', '.key', '.keystore', '.jks', '.properties'))
    blob = path.read_bytes()
    assert b'-----BEGIN PRIVATE KEY-----' not in blob
    if name.endswith(('.env', '.env.example')):
        for line in blob.decode('utf8').splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            assert line.split('=', 1)[0] in {'BASE_URL', 'BASE_URL_WEB'}
    manifest[name] = {'size': len(blob), 'sha256': hashlib.sha256(blob).hexdigest()}
destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(destination, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in files:
        archive.write(path, path.relative_to(source).as_posix())
    archive.writestr('GBOU-STATIC-MANIFEST.json', json.dumps(manifest))
print(json.dumps({'archive': str(destination), 'files': len(files),
                  'uncompressed_bytes': sum(value['size'] for value in manifest.values()),
                  'archive_bytes': destination.stat().st_size,
                  'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}))
