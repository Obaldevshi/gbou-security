"""Apply static UI only; no service, key, database, binding or network mutation."""
from pathlib import Path
from urllib.request import urlopen
import hashlib
import json
import os
import shutil
import sys
import tempfile
import zipfile

assert os.geteuid()==0
archive=Path(sys.argv[1])
expected=sys.argv[2]
assert hashlib.sha256(archive.read_bytes()).hexdigest()==expected
root=Path('/var/lib/gbou-kiosk')
web=root/'web'
names={'index.html','app.css','app.js','version.js'}
assert web.is_dir() and not web.is_symlink()
# Do not let the normal updater immediately restore an older published UI.
with urlopen('https://gbousecurity.ru/kiosk/manifest.json',timeout=20) as response:
    public=json.load(response)
with zipfile.ZipFile(archive) as bundle:
    assert set(bundle.namelist())==names|{'manifest.json'}
    manifest=json.loads(bundle.read('manifest.json'))
    assert manifest==public and set(manifest['files'])==names
    payloads={name:bundle.read(name) for name in names}
    for name,data in payloads.items():
        info=manifest['files'][name]
        assert 0<len(data)<=524288 and len(data)==info['size']
        assert hashlib.sha256(data).hexdigest()==info['sha256']
    assert manifest['version'].encode() in payloads['version.js']
    held=Path('/var/lib/gbou-reprovision/20261019T203825Z/school-data/school.sqlite3')
    assert Path('/var/lib/gbou-reprovision/in-progress').is_file() and held.is_file()
    before=(held.stat().st_ino,hashlib.sha256(held.read_bytes()).digest())
    backup=Path(tempfile.mkdtemp(prefix='ui-before-manual-keyboard-',dir=root))
    for name in names:
        assert (web/name).is_file() and not (web/name).is_symlink()
        shutil.copy2(web/name,backup/name)
    with tempfile.TemporaryDirectory(prefix='.ui-stage-',dir=root) as temporary:
        stage=Path(temporary)
        for name,data in payloads.items():
            (stage/name).write_bytes(data)
            (stage/name).chmod(0o644)
        for name in ('index.html','app.css','app.js','version.js'):
            os.replace(stage/name,web/name)
    assert before==(held.stat().st_ino,hashlib.sha256(held.read_bytes()).digest())
    with urlopen('http://127.0.0.1:8765/local/version',timeout=5) as response:
        assert json.load(response)['version']==manifest['version']
    print(json.dumps({'ui_version':manifest['version'],'held_database_unchanged':True,
        'binding_unchanged':True,'rollback_ui':str(backup)}))
