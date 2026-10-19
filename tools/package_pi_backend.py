"""Package program sources only. No environment, database, venv or device keys."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / 'init-api'
files = sorted(p for folder in ('app', 'scripts') for p in (source / folder).rglob('*.py')
               if '__pycache__' not in p.parts and not p.is_symlink())
manifest = {}
destination = root / 'release/pi-backend-1.7.0-12.zip'
with zipfile.ZipFile(destination, 'x', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        data = path.read_bytes()
        assert b'-----BEGIN PRIVATE KEY-----' not in data
        name = path.relative_to(source).as_posix()
        archive.writestr(name, data)
        manifest[name] = hashlib.sha256(data).hexdigest()
    archive.writestr('MANIFEST.json', json.dumps(manifest))
print(json.dumps({'files': len(files), 'archive': destination.name,
                  'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}))
