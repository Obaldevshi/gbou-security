"""Read-only manifest polling with explicit installation/apply gate.

Run under root via a systemd timer only after owner approval. An HTTP failure
never replaces the last working configuration. TLS ends on each school Pi.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler
from urllib.parse import urlsplit

from managed_routes import validate_routes, render_haproxy, render_wireguard


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def read_private(path):
    if path.is_symlink() or path.stat().st_mode & 0o077:
        raise ValueError('Credential/settings must be a regular private0600 file')
    return path.read_text()


def write_private(path, value):
    with path.open('x') as stream:
        path.chmod(0o600)
        stream.write(value)
        stream.flush()
        os.fsync(stream.fileno())


def atomic_install(source, destination):
    # ProtectSystem=strict uses separate writable bind mounts. A direct rename
    # from /var/lib into /etc can fail with EXDEV even on the same disk.
    descriptor, temporary = tempfile.mkstemp(prefix='.gbou-managed-', dir=destination.parent)
    try:
        with os.fdopen(descriptor, 'wb') as stream, source.open('rb') as original:
            shutil.copyfileobj(original, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def ensure_managed_route():
    """syncconf updates cryptographic peers, but does not install kernel routes."""
    current = subprocess.check_output(
        ['ip', '-4', '-json', 'route', 'show', 'exact', '10.78.0.0/16'], text=True)
    routes = json.loads(current)
    if routes:
        if len(routes) != 1 or routes[0].get('dev') != 'gbou-wg' or routes[0].get('gateway'):
            raise ValueError('Managed address pool conflicts with an existing kernel route')
        return False
    subprocess.run(['ip', '-4', 'route', 'add', '10.78.0.0/16', 'dev', 'gbou-wg',
                    'proto', 'static'], check=True, capture_output=True)
    return True


def route_key(row):
    return (f"{row['school_id']}:{row['building_id']}" if row.get('building_id') is not None
            else str(row['school_id']))


def validate_generations(previous, manifest, preserved=()):
    """Floor by stable host AND building, not the maximum of a whole school."""
    hosts = previous.get('host_generations', {})
    floors = previous.get('generations', {})
    for row in manifest['routes']:
        floor = floors.get(route_key(row), 0)
        known = hosts.get(row['hostname'])
        if known:
            if (known['school_id'] != row['school_id'] or
                    (known.get('building_id') is not None and known['building_id'] != row.get('building_id'))):
                raise ValueError('Stable hostname ownership changed')
            floor = max(floor, known['generation'])
        elif row.get('building_id') is not None and str(row['school_id']) in floors:
            # One successful legacy poll with this new worker records hosts.
            # Existing explicit legacy pins also provide a safe upgrade path.
            pins = [p for p in preserved if p.get('school_id') == row['school_id']]
            if any(p['hostname'] == row['hostname'] for p in pins):
                floor = max(floor, floors[str(row['school_id'])])
            elif not pins and not any(h['school_id'] == row['school_id'] for h in hosts.values()):
                raise ValueError('Cannot map old school generation: run legacy preflight first')
        if row['generation'] < floor:
            raise ValueError('Stale topology generation')


def save_managed_state(path, previous, manifest):
    next_state = {'keys': [r['public_key'] for r in manifest['routes']],
                  'generations': previous['generations'] | {route_key(r): r['generation'] for r in manifest['routes']}}
    hosts = dict(previous.get('host_generations', {}))
    for row in manifest['routes']:
        if 'hostname' in row:
            hosts[row['hostname']] = {key: row.get(key) for key in ('school_id', 'building_id', 'generation')}
    if hosts:
        next_state['host_generations'] = hosts
    if path.exists() and json.loads(path.read_text()) == next_state:
        return
    with tempfile.TemporaryDirectory(prefix='state-', dir=path.parent) as folder:
        candidate = Path(folder) / 'next-state.json'
        write_private(candidate, json.dumps(next_state))
        atomic_install(candidate, path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path, default=Path('/etc/gbou-gateway/managed.json'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Root is required on gateway')
    import fcntl
    runtime = Path('/run/gbou-gateway')
    runtime.mkdir(mode=0o700, exist_ok=True)
    lock_fd = os.open(runtime / 'reconcile.lock', os.O_CREAT | os.O_RDWR, 0o600)
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    config = json.loads(read_private(args.config))
    url = config['manifest_url']
    parts = urlsplit(url)
    if parts.scheme != 'https' or not parts.hostname or parts.username or parts.password or parts.query or parts.fragment or parts.path != '/api/v1/devices/gateway-manifest':
        raise ValueError('Only the trusted central HTTPS manifest endpoint is allowed')
    token = read_private(Path(config['token_file'])).strip()
    if not 40 <= len(token) <= 128:
        raise ValueError('Invalid dedicated manifest credential')
    opener = build_opener(NoRedirect(), ProxyHandler({}))
    with opener.open(Request(url, headers={'X-Gateway-Token': token, 'Accept': 'application/json'}), timeout=20) as response:
        if response.status != 200:
            raise ValueError('Manifest not available; keeping previous configuration')
        body = response.read(1024 * 1024 + 1)
    if len(body) > 1024 * 1024:
        raise ValueError('Manifest exceeds size limit')
    manifest = json.loads(body)
    routes = validate_routes(manifest, config.get('preserved_routes', []))
    haproxy = Path('/etc/haproxy/haproxy.cfg')
    wireguard = Path('/etc/wireguard/gbou-wg.conf')
    state = Path('/var/lib/gbou-gateway/managed-state.json')
    state.parent.mkdir(mode=0o700, exist_ok=True)
    previous = json.loads(state.read_text()) if state.exists() else {'keys': [], 'generations': {}}
    # Do not allow a stale central response to revert an already applied generation.
    validate_generations(previous, manifest, config.get('preserved_routes', []))
    rendered = render_haproxy(routes)
    current_wg = read_private(wireguard)
    rendered_wg = render_wireguard(current_wg, set(previous['keys']), routes)
    with tempfile.TemporaryDirectory(prefix='managed-', dir=state.parent) as work:
        candidate = Path(work) / 'haproxy.cfg'
        write_private(candidate, rendered)
        subprocess.run(['haproxy', '-c', '-f', str(candidate)], check=True, capture_output=True)
        wg_candidate = Path(work) / 'wireguard.conf'
        write_private(wg_candidate, rendered_wg)
        # wg-quick strip validates/strips Address without taking the link down.
        stripped = subprocess.run(['wg-quick', 'strip', str(wg_candidate)], check=True, capture_output=True, text=True).stdout
        if not args.apply:
            print(f'Dry run validated: {len(manifest["routes"])} managed routes; no files/services changed')
            return
        if config.get('apply_approved') is not True:
            raise SystemExit('Explicit installation/publication approval is required before apply')
        if haproxy.read_text() == rendered and current_wg == rendered_wg:
            ensure_managed_route()
            save_managed_state(state, previous, manifest)
            print('Managed gateway already current')
            return
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        backup = state.parent / ('rollback-' + stamp)
        backup.mkdir(mode=0o700)
        shutil.copyfile(haproxy, backup / 'haproxy.cfg')
        write_private(backup / 'wireguard.conf', current_wg)
        old_runtime = subprocess.check_output(['wg', 'showconf', 'gbou-wg'], text=True)
        write_private(backup / 'wireguard-runtime.conf', old_runtime)
        route_added = False
        try:
            route_added = ensure_managed_route()
            subprocess.run(['wg', 'syncconf', 'gbou-wg', '/dev/stdin'], input=stripped, text=True, check=True, capture_output=True)
            # Atomic file replacement; never wg-quick down on the shared link.
            atomic_install(wg_candidate, wireguard)
            atomic_install(candidate, haproxy)
            subprocess.run(['systemctl', 'reload', 'haproxy'], check=True, capture_output=True)
            subprocess.run(['systemctl', 'is-active', '--quiet', 'haproxy'], check=True)
            save_managed_state(state, previous, manifest)
        except BaseException:
            atomic_install(backup / 'wireguard.conf', wireguard)
            atomic_install(backup / 'haproxy.cfg', haproxy)
            subprocess.run(['wg', 'syncconf', 'gbou-wg', str(backup / 'wireguard-runtime.conf')], capture_output=True)
            subprocess.run(['systemctl', 'reload', 'haproxy'], capture_output=True)
            if route_added:
                subprocess.run(['ip', '-4', 'route', 'del', '10.78.0.0/16', 'dev', 'gbou-wg'], capture_output=True)
            raise
    print(f'Managed gateway applied: {len(manifest["routes"])} routes; private peers and TLS passthrough preserved')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never print configuration, request headers or private WireGuard material.
        raise SystemExit('Gateway reconciliation failed (' + type(error).__name__ + '); inspect protected configuration')
