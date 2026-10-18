"""Operator-only static web update. Never opens a DB, key, env or service config."""
from pathlib import Path, PurePosixPath
from datetime import datetime, timezone
import hashlib
import json
import os
import stat
import sys
import zipfile


def main():
    assert os.geteuid() == 0, 'Run via sudo'
    archive_path = Path(sys.argv[1])
    assert archive_path.is_absolute() and not archive_path.is_symlink()
    assert archive_path.name == 'school-web-1.6.1-11.zip'
    root = Path('/var/www/gbou-local')
    assert root.is_dir() and not root.is_symlink(), 'Inspect the existing web root first'
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    stage = root.with_name('gbou-web-stage-' + stamp)
    backup = root.with_name('gbou-web-before-1.6.1-11-' + stamp)
    assert not stage.exists() and not backup.exists()
    with zipfile.ZipFile(archive_path) as archive:
        infos = archive.infolist()
        assert len(infos) < 256 and len({info.filename for info in infos}) == len(infos)
        manifest = json.loads(archive.read('GBOU-STATIC-MANIFEST.json'))
        assert set(manifest) | {'GBOU-STATIC-MANIFEST.json'} == {info.filename for info in infos}
        assert sum(info.file_size for info in infos) < 100 * 1024 * 1024
        for info in infos:
            name = PurePosixPath(info.filename)
            assert not name.is_absolute() and '..' not in name.parts and '\\' not in info.filename
            assert not stat.S_ISLNK(info.external_attr >> 16)
            assert info.file_size < 25 * 1024 * 1024
            if info.filename == 'GBOU-STATIC-MANIFEST.json':
                continue
            expected = manifest[info.filename]
            blob = archive.read(info)
            assert len(blob) == expected['size'] and hashlib.sha256(blob).hexdigest() == expected['sha256']
        version = json.loads(archive.read('version.json'))
        assert version['version'] == '1.6.1' and version['build_number'] == '11'
        stage.mkdir(mode=0o755)
        for name in manifest:
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            with target.open('xb') as stream:
                stream.write(archive.read(name))
            target.chmod(0o644)
    # Only static directories, verified exact parent; no recursive deletion.
    assert stage.parent == backup.parent == root.parent == Path('/var/www')
    os.rename(root, backup)
    try:
        os.rename(stage, root)
    except BaseException:
        os.rename(backup, root)
        raise
    print(json.dumps({'state': 'static_web_updated', 'version': '1.6.1+11',
                      'files': len(manifest), 'rollback_static_directory': str(backup),
                      'database_or_credentials_changed': False}))


if __name__ == '__main__':
    main()
