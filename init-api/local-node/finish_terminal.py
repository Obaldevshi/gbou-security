#!/usr/bin/env python3
"""Retry one approved child-kiosk connection; never configure a primary."""
import json
from pathlib import Path
from device_enroll import private_write
from configure_terminal import main as configure

ROOT = Path('/etc/gbou-device')


def main():
    root = ROOT
    document = root / 'device.json'
    if not document.exists() or (root / 'terminal-configured.json').exists():
        return
    data = json.loads(document.read_text())
    if data['role'] != 'terminal':
        return
    configure()  # Revalidates active registration, HTTPS readiness and no DB/API.
    private_write(root / 'terminal-configured.json', json.dumps({'device_id': data['device_id']}) + '\n')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Approved child setup not ready; retry later. Private details omitted.')
