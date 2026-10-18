"""Prepare primary network assets without starting or replacing ANY service.

An operator installs the candidates only after the explicit cutover checklist.
The universal script deliberately refuses to alter the live school2 topology.
"""
import json
import os
from pathlib import Path
import subprocess
from render_primary_site import render_primary_site


def private_write(path, value):
    with path.open('x') as stream:
        path.chmod(0o600)
        stream.write(value)


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run as root on the NEW primary Pi')
    root = Path('/etc/gbou-device')
    data = json.loads((root / 'device.json').read_text())
    assert data['role'] == 'primary'
    target = root / 'network-candidates'
    target.mkdir(mode=0o700)
    # Existing LAN vhosts must already reject actual gateway source .1.
    current = Path('/etc/caddy/Caddyfile').read_text()
    if 'tls internal' in current and not ('remote_ip 10.77.203.1' in current and 'respond @gateway 404' in current):
        raise SystemExit('First isolate LAN vhosts from gateway, as documented; no files installed')
    if data['hostname'] in current:
        raise SystemExit('Public vhost already exists; do not replace a working configuration blindly')
    private_write(target / 'Caddyfile', current + '\n' + render_primary_site(data['hostname']))
    subprocess.run(['caddy', 'validate', '--config', str(target / 'Caddyfile'), '--adapter', 'caddyfile'],
                   check=True, capture_output=True)
    # Interface name stays short and predictable for wg-quick.
    private_write(target / 'gbou-wg.conf', (root / 'gbou-wg.conf').read_text())
    ip = data['tunnel_ip']
    private_write(target / 'gbou-pi-link.nft', '''table inet gbou_pi_link {
    chain input {
        type filter hook input priority -20; policy accept;
        iifname "gbou-wg" ip saddr 10.77.203.1 tcp dport { 80, 443 } accept
        iifname "gbou-wg" ip saddr 10.77.203.1 ip protocol icmp accept
        iifname "gbou-wg" drop
    }
    chain forward {
        type filter hook forward priority -20; policy accept;
        iifname "gbou-wg" drop
        oifname "gbou-wg" drop
    }
}
''')
    print('Network candidates validated for https://' + data['hostname'] + ' at ' + ip)
    print('NO Caddy, firewall, WireGuard, API, database or existing kiosk configuration changed.')
    print('Apply only after DNS approval, database/USB verification and previous-primary fencing.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Primary preparation failed (' + type(error).__name__ + '); private details omitted')
