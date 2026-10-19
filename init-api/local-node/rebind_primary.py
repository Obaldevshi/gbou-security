"""Verified same-school primary rebind, shared by the local control service.

Run as root with the existing API venv. No cloud mutations, no key output,
no erasure of a database, no activation. Originals are quarantined on the SD;
USB AES-GCM snapshots and a verified configuration bundle precede every move.
The operator must restore/verify the held database BEFORE manual activation.
"""
from contextlib import closing
from datetime import datetime, timezone
import argparse
import configparser
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time
import traceback
import pwd
from urllib.request import Request, build_opener, ProxyHandler, HTTPRedirectHandler

ROOT = Path('/var/lib/gbou-reprovision')
MARKER = ROOT / 'in-progress'
DB = Path('/var/lib/gbou-local/school.sqlite3')
USB = Path('/mnt/gbou-backup')
CLOUD = 'https://obaldevshi-gbou-security-ac8a.twc1.net'
SCHOOL_ID = None
BUILDING_ID = None
KIOSK_USER = os.environ.get('GBOU_KIOSK_USER', 'admin')
DESKTOP = Path(pwd.getpwnam(KIOSK_USER).pw_dir) / '.config/autostart/gbou-kiosk.desktop'
TIMERS = ('gbou-local-sync.timer', 'gbou-local-backup.timer',
          'gbou-device-heartbeat.timer', 'gbou-tls-clock-guard.timer')
BLOCKED = ('gbou-local-api.service', 'gbou-local-sync.service',
           'gbou-local-backup.service', 'gbou-device-heartbeat.service',
           'gbou-tls-clock-guard.service', 'wg-quick@gbou-wg.service', 'caddy.service')
MOVES = (('/var/lib/gbou-local', 'school-data'),
         ('/etc/gbou-local', 'school-config'),
         ('/etc/gbou-device', 'device-before'),
         ('/etc/wireguard/gbou-wg.conf', 'wireguard-before.conf'))


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def private_new(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        stream.write(value)
        stream.flush()
        os.fsync(stream.fileno())
    sync_dir(path.parent)


def record(folder, state):
    candidate = folder / 'state-next.json'
    private_new(candidate, json.dumps(state, indent=2) + '\n')
    os.replace(candidate, folder / 'state.json')
    sync_dir(folder)


def fingerprint(path):
    with closing(sqlite3.connect(f'file:{path}?mode=ro', uri=True)) as db:
        db.execute('BEGIN')
        assert db.execute('PRAGMA integrity_check').fetchone() == ('ok',)
        assert db.execute('PRAGMA foreign_key_check').fetchone() is None
        tables = [r[0] for r in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
        result = {}
        for table in tables:
            assert table.replace('_', '').isalnum()
            rows = db.execute(f'SELECT * FROM "{table}" ORDER BY rowid').fetchall()
            encoded = json.dumps(rows, ensure_ascii=False, separators=(',', ':'),
                                 default=lambda value: value.hex()).encode()
            result[table] = {'count': len(rows), 'sha256': hashlib.sha256(encoded).hexdigest()}
        assert SCHOOL_ID and db.execute('SELECT id FROM schools').fetchall() == [(SCHOOL_ID,)]
        assert isinstance(BUILDING_ID, int) and BUILDING_ID > 0
        assert db.execute('SELECT id,school_id FROM school_buildings').fetchall() == [(BUILDING_ID, SCHOOL_ID)]
        # A same-school QR must not expose a neighbour building's data. Check
        # inactive/deleted rows too; no filtering or deletion "fixes" the scope.
        for table in tables:
            columns = {row[1] for row in db.execute(f'PRAGMA table_info("{table}")')}
            if 'school_id' in columns:
                assert db.execute(f'SELECT 1 FROM "{table}" WHERE school_id IS NOT NULL AND school_id<>? LIMIT 1', (SCHOOL_ID,)).fetchone() is None
            if 'building_id' in columns:
                assert db.execute(f'SELECT 1 FROM "{table}" WHERE building_id IS NOT NULL AND building_id<>? LIMIT 1', (BUILDING_ID,)).fetchone() is None
        schema = db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name").fetchall()
        return {'tables': result, 'schema_sha256': hashlib.sha256(json.dumps(schema).encode()).hexdigest()}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def old_ownership():
    document = json.loads(Path('/etc/gbou-device/device.json').read_text())
    assert document['school_id'] == SCHOOL_ID and document['role'] == 'primary'
    assert document['building_id'] == BUILDING_ID
    assert __import__('re').fullmatch(r'[a-z0-9-]+\.gbousecurity\.ru', document['hostname'])
    token_path = Path(document.get('token_file', '/etc/gbou-device/device.token'))
    assert str(token_path) in {'/etc/gbou-local/node.token', '/etc/gbou-device/device.token'}
    assert not token_path.is_symlink() and not token_path.stat().st_mode & 0o077
    token = token_path.read_text().strip()
    opener = build_opener(ProxyHandler({}), NoRedirect())
    with opener.open(Request(CLOUD + '/api/v1/devices/heartbeat', data=b'',
                     headers={'X-School-Device-Token': token}), timeout=25) as response:
        status = json.loads(response.read(32768))
    assert status['device_id'] == document['device_id']
    assert status['role'] == 'primary' and status['state'] == 'active' and status['is_primary']
    assert status['hostname'] == document['hostname']
    return {key: status[key] for key in ('device_id', 'hostname', 'generation')}


def access_config_fingerprints():
    """Private consistency guard only; never emit network names/configuration."""
    files = [Path('/etc/ssh/sshd_config')]
    for root in (Path('/etc/ssh/sshd_config.d'),
                 Path('/etc/NetworkManager/system-connections'), Path('/etc/wpa_supplicant')):
        if root.is_dir():
            files.extend(path for path in root.rglob('*') if path.is_file())
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in files if path.is_file()}


def prepare(source):
    assert os.geteuid() == 0 and not MARKER.exists()
    assert run('timedatectl', 'show', '-p', 'NTPSynchronized', '--value') == 'yes'
    assert USB.is_mount() and USB.stat().st_dev != DB.stat().st_dev
    for source_path, _ in MOVES:
        path = Path(source_path)
        assert path.exists() and not path.is_symlink() and path.resolve() == path
    assert DESKTOP.is_file() and not DESKTOP.is_symlink()
    for name in ('pairing_agent.py', 'device_enroll.py', 'gbou-device-setup.service'):
        assert (source / name).is_file() and not (source / name).is_symlink()
    setup_unit = Path('/etc/systemd/system/gbou-device-setup.service')
    if setup_unit.exists():
        # A completed earlier QR round leaves the known unit disabled. Preserve
        # it, but never replace an active, foreign or unexpectedly modified unit.
        assert setup_unit.is_file() and not setup_unit.is_symlink()
        assert run('systemctl', 'show', setup_unit.name, '-p', 'ActiveState', '--value') == 'inactive'
        assert run('systemctl', 'show', setup_unit.name, '-p', 'UnitFileState', '--value') == 'disabled'
        assert setup_unit.read_bytes().replace(b'\r\n', b'\n') == (source / setup_unit.name).read_bytes().replace(b'\r\n', b'\n')
    access_before = access_config_fingerprints()
    ownership = old_ownership()
    for unit in ('gbou-local-api', 'gbou-kiosk', 'caddy', 'wg-quick@gbou-wg'):
        assert run('systemctl', 'is-active', unit) == 'active'
    # Finish a normal encrypted backup before the maintenance window.
    run('systemctl', 'start', 'gbou-local-backup.service')
    assert run('systemctl', 'show', 'gbou-local-backup.service', '-p', 'Result', '--value') == 'success'
    ROOT.mkdir(mode=0o700, exist_ok=True)
    assert not ROOT.is_symlink()
    ROOT.chmod(0o700)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    folder = ROOT / stamp
    folder.mkdir(mode=0o700)
    if setup_unit.exists():
        shutil.copy2(setup_unit, folder / 'gbou-device-setup.service.before')
    state = {'version': 1, 'phase': 'preflight', 'operation': stamp,
             'old_primary': ownership, 'moves': [], 'dropins': [],
             'access_config_fingerprints': access_before, 'school_id': SCHOOL_ID,
             'building_id': BUILDING_ID, 'managed_by': 'local-rebind-v1'}
    record(folder, state)
    # Stop all school writers before taking the FINAL database snapshot.
    run('systemctl', 'stop', *TIMERS)
    run('systemctl', 'stop', 'gbou-local-sync.service', 'gbou-local-backup.service',
        'gbou-device-heartbeat.service', 'gbou-tls-clock-guard.service', 'gbou-local-api.service')
    assert run('systemctl', 'show', 'gbou-local-api.service', '-p', 'ActiveState', '--value') == 'inactive'
    sys.path.insert(0, '/opt/gbou-local-api')
    from dotenv import load_dotenv
    load_dotenv('/etc/gbou-local/api.env', override=True)
    from scripts.local_node import _decrypt_file, _encrypt_file
    secret = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
    baseline = fingerprint(DB)
    # The normal backup service stamps local_meta AFTER its snapshot. Make a
    # separate frozen recovery so even that metadata matches exactly; never
    # loosen the comparison or exclude an entire table to conceal differences.
    archive = USB / ('reprovision-db-' + stamp + '.sqlite.gbou')
    with tempfile.TemporaryDirectory(prefix='verify-', dir=folder) as work:
        work = Path(work)
        snapshot = work / 'frozen.sqlite3'
        with closing(sqlite3.connect(f'file:{DB}?mode=ro', uri=True)) as live, \
                closing(sqlite3.connect(snapshot)) as target:
            live.backup(target)
        assert fingerprint(snapshot) == baseline
        _encrypt_file(snapshot, archive, secret)
        recovered = work / 'verified.sqlite3'
        _decrypt_file(archive, recovered, secret)
        assert fingerprint(recovered) == baseline
        # Keep an encrypted, independently verified recovery of configuration too.
        plain = work / 'configuration.tar'
        with tarfile.open(plain, 'w') as tar:
            for name in ('/etc/gbou-local', '/etc/gbou-device', '/etc/wireguard/gbou-wg.conf',
                         '/etc/gbou-kiosk.conf', '/etc/caddy/Caddyfile', '/var/lib/caddy',
                         str(DESKTOP)):
                tar.add(name, arcname=name.lstrip('/'), recursive=True)
            tar.add(recovered, arcname='school.sqlite3', recursive=False)
            metadata = json.dumps({'format': 'gbou-reprovision-v1', 'baseline': baseline}).encode()
            entry = tarfile.TarInfo('recovery-manifest.json')
            entry.size, entry.mode = len(metadata), 0o600
            tar.addfile(entry, io.BytesIO(metadata))
        bundle = USB / ('reprovision-' + stamp + '.tar.gbou')
        _encrypt_file(plain, bundle, secret)
        check = work / 'configuration-restored.tar'
        _decrypt_file(bundle, check, secret)
        assert hashlib.sha256(plain.read_bytes()).digest() == hashlib.sha256(check.read_bytes()).digest()
        with tarfile.open(check) as tar:
            assert json.load(tar.extractfile('recovery-manifest.json'))['baseline'] == baseline
            extra = work / 'bundle-verified.sqlite3'
            with extra.open('xb') as stream:
                shutil.copyfileobj(tar.extractfile('school.sqlite3'), stream)
            assert fingerprint(extra) == baseline
    state.update(phase='backed_up', baseline=baseline, database_inode=DB.stat().st_ino,
                 usb_database=archive.name, usb_configuration=bundle.name,
                 bundle_sha256=hashlib.sha256(bundle.read_bytes()).hexdigest())
    record(folder, state)
    # Reboot-safe fencing, BEFORE retiring/moving any registration or data.
    private_new(MARKER, str(folder) + '\n')
    for unit in BLOCKED:
        directory = Path('/etc/systemd/system') / (unit + '.d')
        directory.mkdir(mode=0o755, exist_ok=True)
        assert not directory.is_symlink()
        dropin = directory / '80-gbou-reprovision.conf'
        private_new(dropin, '[Unit]\nConditionPathExists=!/var/lib/gbou-reprovision/in-progress\n')
        state['dropins'].append(str(dropin))
        record(folder, state)
    run('systemctl', 'daemon-reload')
    run('systemctl', 'stop', 'caddy.service', 'wg-quick@gbou-wg.service')
    assert run('systemctl', 'show', 'wg-quick@gbou-wg.service', '-p', 'ActiveState', '--value') == 'inactive'
    assert fingerprint(DB) == baseline
    desktop = DESKTOP
    shutil.copy2(desktop, folder / 'autostart.before')
    shutil.copy2('/etc/gbou-kiosk.conf', folder / 'kiosk.conf.before')
    for old, held in MOVES:
        target = folder / held
        assert not target.exists() and Path(old).stat().st_dev == folder.stat().st_dev
        os.rename(old, target)
        sync_dir(Path(old).parent)
        sync_dir(folder)
        state['moves'].append([old, held])
        record(folder, state)
    assert fingerprint(folder / 'school-data/school.sqlite3') == baseline
    assert (folder / 'school-data/school.sqlite3').stat().st_ino == state['database_inode']
    Path('/etc/gbou-device').mkdir(mode=0o700)
    install = Path('/opt/gbou-device-setup')
    install.mkdir(mode=0o755, exist_ok=True)
    for name in ('pairing_agent.py', 'device_enroll.py'):
        destination = install / name
        if destination.exists():
            shutil.copy2(destination, folder / (name + '.before'))
        if (source / name).resolve() != destination.resolve():
            shutil.copyfile(source / name, destination)
        destination.chmod(0o755)
    unit = Path('/etc/systemd/system/gbou-device-setup.service')
    shutil.copyfile(source / unit.name, unit)
    unit.chmod(0o644)
    # The normal kiosk contains the status/QR dialog and survives reboot. Do not
    # redirect the browser to an agent which is stopped before data restoration.
    sync_dir(desktop.parent)
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', '--now', 'gbou-device-setup.service')
    ready = False
    opener = build_opener(ProxyHandler({}), NoRedirect())
    for _ in range(20):
        try:
            with opener.open('http://127.0.0.1:8766/state', timeout=3) as response:
                public = json.loads(response.read(524288))
            if public.get('qr') and len(public.get('code', '')) == 6:
                ready = True
                break
        except OSError:
            pass
        time.sleep(3)
    state['phase'] = 'qr_ready' if ready else 'qr_waiting_network'
    assert access_config_fingerprints() == access_before
    record(folder, state)
    print(json.dumps({'phase': state['phase'], 'operation': stamp,
        'school_data_preserved': fingerprint(folder / 'school-data/school.sqlite3') == baseline,
        'usb_database_verified': True, 'usb_configuration_verified': True,
        'old_writer_stopped': True, 'wifi_and_ssh_configuration_unchanged': True,
        'counts': {k: v['count'] for k, v in baseline['tables'].items()},
        'next': 'Register SAME school as PRIMARY; activate only after local data verification.'}))


def status():
    assert os.geteuid() == 0
    if not MARKER.exists():
        print(json.dumps({'in_progress': False}))
        return
    folder = Path(MARKER.read_text().strip())
    assert folder.parent == ROOT and folder.resolve() == folder
    state = json.loads((folder / 'state.json').read_text())
    enrolled = Path('/etc/gbou-device/device.json')
    public = json.loads(enrolled.read_text()) if enrolled.exists() else None
    print(json.dumps({'in_progress': True, 'phase': state['phase'], 'operation': state['operation'],
        'data_held': (folder / 'school-data/school.sqlite3').exists(),
        'database_restored_but_fenced': DB.exists(),
        'new_registration': None if not public else {k: public.get(k) for k in
          ('device_id', 'school_id', 'building_id', 'role', 'state', 'hostname')},
        'cloud_activation_performed_by_this_script': False}))


def restore_pending():
    """Return the verified SAME database; keep all writers fenced for activation."""
    assert os.geteuid() == 0 and MARKER.is_file()
    folder = Path(MARKER.read_text().strip())
    assert folder.parent == ROOT and folder.resolve() == folder
    state = json.loads((folder / 'state.json').read_text())
    assert state['phase'] == 'qr_ready'
    held = folder / 'school-data/school.sqlite3'
    assert not DB.parent.exists() and not Path('/etc/gbou-local').exists()
    assert fingerprint(held) == state['baseline']
    assert held.stat().st_ino == state['database_inode']
    for unit in ('gbou-local-api.service', 'wg-quick@gbou-wg.service', 'caddy.service'):
        assert run('systemctl', 'show', unit, '-p', 'ActiveState', '--value') == 'inactive'
    root = Path('/etc/gbou-device')
    document = json.loads((root / 'device.json').read_text())
    assert document['device_id'] != state['old_primary']['device_id']
    assert document['school_id'] == SCHOOL_ID and document['role'] == 'primary'
    assert isinstance(BUILDING_ID, int) and document['building_id'] == BUILDING_ID
    assert document['hostname'] == state['old_primary']['hostname']
    assert json.loads((root / 'pairing-state.json').read_text()).get('completed') is True
    token_path = root / 'device.token'
    assert not token_path.is_symlink() and not token_path.stat().st_mode & 0o077
    token = token_path.read_text().strip()
    assert re_full_token(token)
    opener = build_opener(ProxyHandler({}), NoRedirect())
    with opener.open(Request(CLOUD + '/api/v1/devices/heartbeat', data=b'',
            headers={'X-School-Device-Token': token}), timeout=25) as response:
        current = json.loads(response.read(32768))
    assert current['device_id'] == document['device_id'] and current['role'] == 'primary'
    assert current['hostname'] == document['hostname']
    assert current['state'] in {'pending', 'active'}
    assert current['is_primary'] == (current['state'] == 'active')
    import ipaddress
    assert ipaddress.ip_address(document['tunnel_ip']) in ipaddress.ip_network('10.78.0.0/16')
    candidate = root / 'gbou-wg.conf'
    assert not candidate.is_symlink() and not candidate.stat().st_mode & 0o077
    network = configparser.ConfigParser(interpolation=None)
    network.read(candidate)
    assert set(network.sections()) == {'Interface', 'Peer'}
    assert network['Interface']['Address'] == document['tunnel_ip'] + '/32'
    assert network['Interface']['PrivateKey'] == (root / 'wireguard.key').read_text().strip()
    assert network['Peer']['AllowedIPs'] == '10.77.203.1/32'
    assert network['Peer']['PublicKey'] == document['gateway_public_key']
    assert network['Peer']['Endpoint'] == document['gateway_endpoint']
    assert not Path('/etc/wireguard/gbou-wg.conf').exists()
    assert USB.is_mount() and USB.stat().st_dev != held.stat().st_dev
    sys.path.insert(0, '/opt/gbou-local-api')
    from dotenv import load_dotenv, dotenv_values
    old_config = folder / 'school-config'
    values = dotenv_values(old_config / 'api.env')
    assert values.get('GBOU_NODE_TOKEN_FILE', '/etc/gbou-local/node.token') == '/etc/gbou-local/node.token'
    assert values.get('GBOU_BUILDING_ID') in {None, str(BUILDING_ID)}
    load_dotenv(old_config / 'api.env', override=True)
    from scripts.local_node import _decrypt_file
    secret = (old_config / 'backup.passphrase').read_text().strip()
    bundle = USB / state['usb_configuration']
    assert hashlib.sha256(bundle.read_bytes()).hexdigest() == state['bundle_sha256']
    with tempfile.TemporaryDirectory(prefix='before-return-', dir=folder) as work:
        recovered = Path(work) / 'verified.sqlite3'
        _decrypt_file(USB / state['usb_database'], recovered, secret)
        assert fingerprint(recovered) == state['baseline']
    run('systemctl', 'stop', 'gbou-device-setup.service')
    state.update(phase='returning_data_fenced', new_device_id=document['device_id'],
                 central_state_before_return=current['state'], restored=[])
    record(folder, state)
    for name, target in [('school-data', DB.parent), ('school-config', Path('/etc/gbou-local'))]:
        assert not target.exists() and (folder / name).stat().st_dev == target.parent.stat().st_dev
        os.rename(folder / name, target)
        sync_dir(target.parent)
        sync_dir(folder)
        state['restored'].append(str(target))
        record(folder, state)
    assert fingerprint(DB) == state['baseline'] and DB.stat().st_ino == state['database_inode']
    if document.get('node_scope') == 'building':
        from dotenv import set_key
        env_file = Path('/etc/gbou-local/api.env')
        env_owner = env_file.stat()
        set_key(str(env_file), 'GBOU_BUILDING_ID', str(BUILDING_ID))
        os.chown(env_file, env_owner.st_uid, env_owner.st_gid)
        env_file.chmod(0o600)
    old_token = Path('/etc/gbou-local/node.token')
    assert not old_token.is_symlink() and not old_token.stat().st_mode & 0o077
    owner = old_token.stat()
    private_new(folder / 'node.token.before-new', old_token.read_text())
    temporary = old_token.with_suffix('.reprovision-next')
    private_new(temporary, token + '\n')
    os.chown(temporary, owner.st_uid, owner.st_gid)
    os.replace(temporary, old_token)
    sync_dir(old_token.parent)
    private_new(Path('/etc/wireguard/gbou-wg.conf'), candidate.read_text())
    state.update(phase='data_ready_for_activation', data_verified=True,
                 new_credential_installed=True, new_network_installed_but_stopped=True)
    record(folder, state)
    assert fingerprint(DB) == state['baseline']
    print(json.dumps({'phase': state['phase'], 'central_state': current['state'],
        'same_sqlite_inode': True, 'all_tables_equal': True, 'usb_restore_verified': True,
        'writers_still_fenced': True, 'hostname': document['hostname'],
        'counts': {k: v['count'] for k, v in state['baseline']['tables'].items()},
        'next': 'Owner may now confirm verified activation; do not remove fencing until active ownership is checked.'}))


def re_full_token(value):
    return len(value) == 64 and all(c in '0123456789abcdef' for c in value)


def finish_active():
    """Only start the restored database after the HUMAN has activated its identity."""
    assert os.geteuid() == 0 and MARKER.is_file()
    folder = Path(MARKER.read_text().strip())
    assert folder.parent == ROOT and folder.resolve() == folder
    state = json.loads((folder / 'state.json').read_text())
    assert state['phase'] in {'data_ready_for_activation', 'activated_but_fenced_retry_required'} and state['data_verified']
    assert fingerprint(DB) == state['baseline'] and DB.stat().st_ino == state['database_inode']
    root = Path('/etc/gbou-device')
    document = json.loads((root / 'device.json').read_text())
    assert document['device_id'] == state['new_device_id'] and document['school_id'] == SCHOOL_ID
    assert document['hostname'] == state['old_primary']['hostname'] and document['role'] == 'primary'
    assert document['building_id'] == BUILDING_ID
    token = (root / 'device.token').read_text().strip()
    assert re_full_token(token) and Path('/etc/gbou-local/node.token').read_text().strip() == token
    opener = build_opener(ProxyHandler({}), NoRedirect())
    with opener.open(Request(CLOUD + '/api/v1/devices/heartbeat', data=b'',
            headers={'X-School-Device-Token': token}), timeout=25) as response:
        central = json.loads(response.read(32768))
    assert central['device_id'] == document['device_id'] and central['role'] == 'primary'
    assert central['state'] == 'active' and central['is_primary']
    assert central['hostname'] == document['hostname']
    assert central['generation'] == state['old_primary']['generation'] + 1
    with opener.open(Request(CLOUD + '/api/v1/node/config',
            headers={'X-School-Node-Token': token}), timeout=25) as response:
        config = json.loads(response.read(1048576))['data']
    assert config['school']['id'] == SCHOOL_ID
    assert document['building_id'] in [b['id'] for b in config['buildings']]
    if document.get('node_scope') == 'building':
        assert config.get('building_id') == BUILDING_ID and [b['id'] for b in config['buildings']] == [BUILDING_ID]
    assert run('systemctl', 'is-active', 'gbou-pi-link-firewall.service') == 'active'
    run('caddy', 'validate', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile')
    assert Path('/etc/wireguard/gbou-wg.conf').read_bytes() == (root / 'gbou-wg.conf').read_bytes()
    for dropin in state['dropins']:
        path = Path(dropin)
        assert not path.is_symlink() and path.parent.parent == Path('/etc/systemd/system')
        assert path.read_text() == '[Unit]\nConditionPathExists=!/var/lib/gbou-reprovision/in-progress\n'
    released = folder / 'fence.released'
    assert not released.exists()
    state.update(phase='starting_activated_primary', activated_generation=central['generation'])
    record(folder, state)
    os.rename(MARKER, released)
    sync_dir(ROOT)
    sync_dir(folder)
    try:
        run('systemctl', 'start', 'wg-quick@gbou-wg.service')
        handshake = False
        for _ in range(20):
            rows = run('wg', 'show', 'gbou-wg', 'latest-handshakes').splitlines()
            stamps = [int(row.split()[-1]) for row in rows]
            if len(stamps) == 1 and 0 <= time.time() - stamps[0] < 120:
                handshake = True
                break
            time.sleep(2)
        assert handshake, 'Waiting for managed gateway reconciliation'
        print(json.dumps({'progress': 'new_tunnel_verified_starting_local_api'}), flush=True)
        run('systemctl', 'start', 'gbou-local-api.service')
        ready = False
        for _ in range(60):
            try:
                with opener.open('http://127.0.0.1:8081/ready', timeout=3) as response:
                    ready = response.status == 200
                if ready:
                    break
            except OSError:
                pass
            time.sleep(1)
        assert ready
        print(json.dumps({'progress': 'local_api_ready_verifying_records'}), flush=True)
        # No public clients yet: assert the restored record set BEFORE opening Caddy.
        assert fingerprint(DB) == state['baseline']
        run('systemctl', 'start', 'caddy.service')
        public_ready = False
        for _ in range(8):
            try:
                with opener.open('https://' + document['hostname'] + '/ready', timeout=6) as response:
                    public_ready = response.status == 200
                if public_ready:
                    break
            except OSError:
                pass
            time.sleep(2)
        assert public_ready
    except Exception:
        # This is still the NEW centrally activated identity, never an old-writer rollback.
        if not MARKER.exists():
            os.rename(released, MARKER)
            sync_dir(ROOT)
        subprocess.run(['systemctl', 'stop', 'caddy.service', 'gbou-local-api.service',
                        'wg-quick@gbou-wg.service'], capture_output=True)
        state['phase'] = 'activated_but_fenced_retry_required'
        record(folder, state)
        raise
    state.update(phase='new_primary_online', public_https_verified=True,
                 records_equal_before_public_open=True)
    record(folder, state)
    # Drop only this operation's verified, exact guard files, not other unit settings.
    for dropin in state['dropins']:
        path = Path(dropin)
        path.unlink()
        sync_dir(path.parent)
    run('systemctl', 'daemon-reload')
    document.update(state='active', generation=central['generation'])
    candidate = root / 'device-reprovision-next.json'
    private_new(candidate, json.dumps(document, indent=2) + '\n')
    os.replace(candidate, root / 'device.json')
    sync_dir(root)
    run('systemctl', 'disable', '--now', 'gbou-device-setup.service')
    desktop = DESKTOP
    assert not desktop.is_symlink()
    shutil.copy2(folder / 'autostart.before', desktop)
    import pwd
    user = pwd.getpwnam(KIOSK_USER)
    os.chown(desktop, user.pw_uid, user.pw_gid)
    run('systemctl', 'start', *TIMERS)
    run('systemctl', 'start', 'gbou-local-sync.service', 'gbou-device-heartbeat.service')
    state.update(phase='new_primary_online', timers_restored=True,
                 sync_result=run('systemctl', 'show', 'gbou-local-sync.service', '-p', 'Result', '--value'),
                 heartbeat_result=run('systemctl', 'show', 'gbou-device-heartbeat.service', '-p', 'Result', '--value'))
    record(folder, state)
    print(json.dumps({'phase': state['phase'], 'generation': central['generation'],
        'hostname': document['hostname'], 'public_https_ready': True,
        'all_records_equal_before_public_open': True, 'same_sqlite_inode': True,
        'sync_result': state['sync_result'], 'heartbeat_result': state['heartbeat_result'],
        'cloud_activation_performed_by_this_script': False}))


def backup_current():
    """Authenticated USB recovery of the NEW identity/config and a consistent DB."""
    assert os.geteuid() == 0 and not MARKER.exists() and USB.is_mount()
    assert USB.stat().st_dev != DB.stat().st_dev
    device = json.loads(Path('/etc/gbou-device/device.json').read_text())
    assert device['school_id'] == SCHOOL_ID and device['role'] == 'primary' and device['state'] == 'active'
    matches = []
    for path in ROOT.glob('*/state.json'):
        if not path.is_symlink() and path.resolve() == path:
            state = json.loads(path.read_text())
            if state.get('new_device_id') == device['device_id'] and state['phase'] == 'new_primary_online':
                matches.append((path.parent, state))
    assert len(matches) == 1
    folder, state = matches[0]
    sys.path.insert(0, '/opt/gbou-local-api')
    from dotenv import load_dotenv
    load_dotenv('/etc/gbou-local/api.env', override=True)
    from scripts.local_node import _encrypt_file, _decrypt_file
    secret = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    archive = USB / ('reprovision-current-' + stamp + '.tar.gbou')
    with tempfile.TemporaryDirectory(prefix='current-recovery-', dir=folder) as work:
        work = Path(work)
        snapshot = work / 'snapshot.sqlite3'
        with closing(sqlite3.connect(f'file:{DB}?mode=ro', uri=True)) as source, \
                closing(sqlite3.connect(snapshot)) as target:
            source.backup(target)
        baseline = fingerprint(snapshot)
        plain = work / 'current.tar'
        with tarfile.open(plain, 'w') as tar:
            for path in ('/etc/gbou-local', '/etc/gbou-device', '/etc/wireguard/gbou-wg.conf',
                         '/etc/gbou-kiosk.conf', '/etc/caddy/Caddyfile', '/var/lib/caddy',
                         str(DESKTOP)):
                tar.add(path, arcname=path.lstrip('/'), recursive=True)
            tar.add(snapshot, arcname='school.sqlite3', recursive=False)
        _encrypt_file(plain, archive, secret)
        recovered = work / 'current-verified.tar'
        _decrypt_file(archive, recovered, secret)
        assert hashlib.sha256(plain.read_bytes()).digest() == hashlib.sha256(recovered.read_bytes()).digest()
        with tarfile.open(recovered) as tar:
            check_db = work / 'checked.sqlite3'
            with check_db.open('xb') as stream:
                shutil.copyfileobj(tar.extractfile('school.sqlite3'), stream)
            assert fingerprint(check_db) == baseline
    state.update(current_recovery_bundle=archive.name,
                 current_recovery_bundle_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                 current_recovery_verified=True)
    record(folder, state)
    print(json.dumps({'current_configuration_and_database_restore_verified': True,
                      'archive': archive.name,
                      'counts': {k: v['count'] for k, v in baseline['tables'].items()}}))


if __name__ == '__main__':
    if MARKER.exists():
        context_folder = Path(MARKER.read_text().strip())
        assert context_folder.parent == ROOT and context_folder.resolve() == context_folder
        context = json.loads((context_folder / 'state.json').read_text())
        assert context.get('managed_by') == 'local-rebind-v1'
        SCHOOL_ID, BUILDING_ID = context['school_id'], context['building_id']
    else:
        context = json.loads(Path('/etc/gbou-device/device.json').read_text())
        SCHOOL_ID, BUILDING_ID = context['school_id'], context.get('building_id')
    assert isinstance(SCHOOL_ID, int) and SCHOOL_ID > 0
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'status', 'restore-pending', 'finish-active', 'backup-current'))
    parser.add_argument('--source', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        if args.action == 'prepare':
            if not args.apply or args.source is None:
                raise ValueError('Explicit --apply and staged setup sources required')
            prepare(args.source.resolve())
        elif args.action == 'restore-pending':
            if not args.apply:
                raise ValueError('Explicit --apply required')
            restore_pending()
        elif args.action == 'finish-active':
            if not args.apply:
                raise ValueError('Explicit --apply required')
            finish_active()
        elif args.action == 'backup-current':
            if not args.apply:
                raise ValueError('Explicit --apply required')
            backup_current()
        else:
            status()
    except Exception as error:
        print(json.dumps({'ok': False, 'error_type': type(error).__name__,
            'failure_line': traceback.extract_tb(error.__traceback__)[-1].lineno,
            'fenced': MARKER.exists(),
            'instruction': 'Inspect protected state locally. Never delete held data or bypass fencing.'}))
        raise SystemExit(1)
