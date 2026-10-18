"""Pure renderer: explicit SNI allowlist and TLS passthrough, never arbitrary proxy."""
import base64
import ipaddress
import re


def validate_routes(manifest, legacy=()):
    if manifest.get('schema_version') != 1 or not isinstance(manifest.get('routes'), list):
        raise ValueError('Unknown manifest format')
    routes, hosts, addresses, keys = [], set(), set(), set()
    pinned = {row['hostname']: row for row in legacy}
    if len(pinned) != len(legacy):
        raise ValueError('Duplicate preserved hostname')
    managed_hosts = {row['hostname'] for row in manifest['routes']}
    for row in manifest['routes']:
        pin = pinned.get(row['hostname'])
        if pin and (not isinstance(pin.get('school_id'), int) or pin['school_id'] != row.get('school_id') or not pin.get('public_key')):
            raise ValueError('Legacy route requires an explicit school/key ownership pin')
    combined = [(row, False) for row in legacy if row['hostname'] not in managed_hosts and not row.get('managed_only', False)]
    combined += [(row, True) for row in manifest['routes']]
    for row, managed in combined:
        host = row['hostname']
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.gbousecurity\.ru', host):
            raise ValueError('Forbidden hostname')
        ip = ipaddress.ip_address(row['tunnel_ip'])
        allowed = ipaddress.ip_network('10.78.0.0/16') if managed else ipaddress.ip_network('10.77.203.0/24')
        pin = pinned.get(host) if managed else None
        adopted = bool(pin and row.get('school_id') == pin.get('school_id')
                       and str(ip) == pin['tunnel_ip'] and row.get('public_key') == pin.get('public_key'))
        if ((ip not in allowed and not adopted) or ip in {allowed.network_address, allowed.broadcast_address, ipaddress.ip_address('10.77.203.1')}
                or (adopted and ip not in ipaddress.ip_network('10.77.203.0/24'))):
            raise ValueError('Forbidden tunnel upstream')
        if host in hosts or str(ip) in addresses:
            raise ValueError('Duplicate route or tunnel IP')
        if managed or row.get('public_key'):
            key = row['public_key']
            decoded = base64.b64decode(key, validate=True)
            if len(decoded) != 32 or not any(decoded) or base64.b64encode(decoded).decode() != key or key in keys:
                raise ValueError('Invalid or repeated public key')
            if managed and (not isinstance(row['generation'], int) or row['generation'] < 1):
                raise ValueError('Invalid topology generation')
            keys.add(key)
        hosts.add(host)
        addresses.add(str(ip))
        routes.append(dict(row, managed=managed, adopted_legacy=adopted))
    if len(routes) > 500:
        raise ValueError('Capacity guard: benchmark before exceeding500 routes')
    return routes


def render_haproxy(routes):
    config = '''global
    user haproxy
    group haproxy
    daemon
    maxconn 256
    hard-stop-after 10s
defaults
    mode tcp
    timeout connect 5s
    timeout client 120s
    timeout server 120s
frontend permitted_tls
    bind 0.0.0.0:443
    tcp-request inspect-delay 5s
'''
    if routes:
        hosts = ' '.join(route['hostname'] for route in routes)
        config += f'    acl permitted_sni req.ssl_sni -i {hosts}\n'
        config += '    tcp-request content reject if { req.ssl_hello_type 1 } !permitted_sni\n'
        config += '    tcp-request content accept if { req.ssl_hello_type 1 } permitted_sni\n'
    config += '    tcp-request content reject if WAIT_END\n'
    if routes:
        for index, route in enumerate(routes):
            config += f"    acl school_{index} req.ssl_sni -i {route['hostname']}\n"
            config += f'    use_backend tls_{index} if school_{index}\n'
    config += 'frontend certificate_challenge\n    bind 0.0.0.0:80\n    mode http\n'
    for index, route in enumerate(routes):
        config += f"    acl host_{index} hdr(host),lower -m str {route['hostname']} {route['hostname']}:80\n"
    config += '    acl acme path_beg /.well-known/acme-challenge/\n'
    for index, route in enumerate(routes):
        config += f"    http-request redirect location https://{route['hostname']}/ code 308 if host_{index} !acme\n"
    for index in range(len(routes)):
        config += f'    use_backend acme_{index} if host_{index} acme\n'
    config += '    default_backend reject_http\nbackend reject_http\n    mode http\n    http-request deny deny_status 404\n'
    for index, route in enumerate(routes):
        config += f"backend tls_{index}\n    server pi {route['tunnel_ip']}:443 check\n"
        config += f"backend acme_{index}\n    mode http\n    server pi {route['tunnel_ip']}:80 check\n"
    return config


def render_wireguard(current, managed_old_keys, routes):
    """Preserve interface/private key and ALL unmanaged peers; remove only ours."""
    pieces = re.split(r'(?m)^\[Peer\]\s*$', current)
    output = pieces[0]
    adopted = {r['public_key']: r['tunnel_ip'] for r in routes if r.get('adopted_legacy')}
    retained = {r['public_key'] for r in routes if not r['managed'] and r.get('public_key')}
    unmanaged_keys, unmanaged_ips = set(), set()
    for peer in pieces[1:]:
        match = re.search(r'(?m)^PublicKey\s*=\s*(\S+)\s*$', peer)
        if match is None:
            raise ValueError('Unknown current peer format')
        if match[1] in managed_old_keys and match[1] not in retained:
            continue
        if match[1] in adopted:
            networks = {ipaddress.ip_network(x.strip()) for line in re.findall(r'(?m)^AllowedIPs\s*=\s*(.+)$', peer) for x in line.split(',')}
            if networks != {ipaddress.ip_network(adopted[match[1]] + '/32')}:
                raise ValueError('Legacy peer does not match the pinned narrow address')
            # Explicit ownership transfer, never clone a key or change its IP.
            continue
        unmanaged_keys.add(match[1])
        for line in re.findall(r'(?m)^AllowedIPs\s*=\s*(.+)$', peer):
            unmanaged_ips.update(ipaddress.ip_network(x.strip()) for x in line.split(','))
        output += '[Peer]\n' + peer
    for route in routes:
        if not route['managed']:
            # Explicit operator rollback pin may need its original peer restored.
            if route.get('public_key') and route['public_key'] not in unmanaged_keys:
                output += f"\n[Peer]\nPublicKey = {route['public_key']}\nAllowedIPs = {route['tunnel_ip']}/32\n"
            continue
        if route['public_key'] in unmanaged_keys or any(ipaddress.ip_address(route['tunnel_ip']) in net for net in unmanaged_ips):
            raise ValueError('Managed peer collides with existing unmanaged peer')
        output += f"\n[Peer]\nPublicKey = {route['public_key']}\nAllowedIPs = {route['tunnel_ip']}/32\n"
    return output
