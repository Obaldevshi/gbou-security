"""Package only the four published static assets and their verified manifest."""
from pathlib import Path
import hashlib
import json
import zipfile

root=Path(__file__).resolve().parents[1]
source=root/'init-app/web/kiosk'
manifest=json.loads((source/'manifest.json').read_text())
assert set(manifest['files'])=={'index.html','app.css','app.js','version.js'}
destination=root/f"release/kiosk-ui-{manifest['version']}.zip"
with zipfile.ZipFile(destination,'x',zipfile.ZIP_DEFLATED) as archive:
    for name,info in manifest['files'].items():
        data=(source/name).read_bytes()
        assert len(data)==info['size'] and hashlib.sha256(data).hexdigest()==info['sha256']
        archive.writestr(name,data)
    archive.writestr('manifest.json',json.dumps(manifest))
print(json.dumps({'archive':destination.name,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}))
