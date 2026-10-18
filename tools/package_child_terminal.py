"""Reproducible source-only child bundle. Explicit allowlist, no env or DB."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'release/raspberry-child-20261018'
PREFIX = 'gbou-terminal/'


def build():
    entries = {
        'install-terminal.sh': ROOT / 'init-api/local-node/install-terminal.sh',
        'INSTRUCTION.html': ROOT / 'docs/raspberry-second-device.html',
    }
    for name in ['server.py', 'scripts/install.sh', 'scripts/chromium-kiosk.sh',
                 'systemd/gbou-kiosk.service', 'web/index.html', 'web/app.css',
                 'web/app.js', 'web/version.js']:
        entries['init-kiosk/' + name] = ROOT / 'init-kiosk' / name
    for name in ['install-pairing.sh', 'pairing_agent.py', 'device_enroll.py',
                 'configure_terminal.py', 'finish_terminal.py', 'device_heartbeat.py',
                 'systemd/gbou-device-setup.service', 'systemd/gbou-device-terminal.service',
                 'systemd/gbou-device-terminal.timer', 'systemd/gbou-device-heartbeat.service',
                 'systemd/gbou-device-heartbeat.timer']:
        entries['local-node/' + name] = ROOT / 'init-api/local-node' / name
    contents = {name: source.read_bytes().replace(b'\r\n', b'\n') for name, source in entries.items()}
    manifest = {name: hashlib.sha256(data).hexdigest() for name, data in sorted(contents.items())}
    contents['SHA256SUMS.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    archive = OUTPUT / 'gbou-terminal-20261018.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as target:
        for name, data in sorted(contents.items()):
            info = zipfile.ZipInfo(PREFIX + name, (2026, 10, 18, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100644 << 16)
            target.writestr(info, data)
    with zipfile.ZipFile(archive) as check:
        assert check.testzip() is None
        assert len(check.namelist()) == len(contents)
        for name, expected in manifest.items():
            assert hashlib.sha256(check.read(PREFIX + name)).hexdigest() == expected
            assert b'\r\n' not in check.read(PREFIX + name)
        assert not any(name.endswith(('.sqlite3', '.db', '.env', '.token', '.key')) for name in check.namelist())
    print(json.dumps({'archive': str(archive), 'files': len(contents), 'bytes': archive.stat().st_size,
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    build()
