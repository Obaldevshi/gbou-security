"""Pure renderer: explicit SNI allowlist and TLS passthrough, never arbitrary proxy."""
import base64
import ipaddress
import re


def validate_routes(manifest, legacy=()):
    if manifest.get('schema_version') != 1 or not isinstance(manifest.get('routes'), list):
        raise ValueError('Unknown manifest format')
    routes, hosts, addresses, keys = [], set(), set(), set()
    for row, managed in [(row, False) for row in legacy] + [(row, True) for row in manifest['routes']]:
        host = row['hostname']
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.gbousecurity\.ru', host):
            raise ValueError('Forbidden hostname')
        ip = ipaddress.ip_address(row['tunnel_ip'])
        allowed = ipaddress.ip_network('10.78.0.0/16') if managed else ipaddress.ip_network('10.77.203.0/24')
        if ip not in allowed or ip in {allowed.network_address, allowed.broadcast_address, ipaddress.ip_address('10.77.203.1')}:
            raise ValueError('Forbidden tunnel upstream')
        if host in hosts or str(ip) in addresses:
            raise ValueError('Duplicate route or tunnel IP')
        if managed:
            key = row['public_key']
            decoded = base64.b64decode(key, validate=True)
            if len(decoded) != 32 or not any(decoded) or base64.b64encode(decoded).decode() != key or key in keys:
                raise ValueError('Invalid or repeated public key')
            if not isinstance(row['generation'], int) or row['generation'] < 1:
                raise ValueError('Invalid topology generation')
            keys.add(key)
        hosts.add(host)
        addresses.add(str(ip))
        routes.append(dict(row, managed=managed))
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
    unmanaged_keys, unmanaged_ips = set(), set()
    for peer in pieces[1:]:
        match = re.search(r'(?m)^PublicKey\s*=\s*(\S+)\s*$', peer)
        if match is None:
            raise ValueError('Unknown current peer format')
        if match[1] in managed_old_keys:
            continue
        unmanaged_keys.add(match[1])
        for line in re.findall(r'(?m)^AllowedIPs\s*=\s*(.+)$', peer):
            unmanaged_ips.update(ipaddress.ip_network(x.strip()) for x in line.split(','))
        output += '[Peer]\n' + peer
    for route in routes:
        if not route['managed']:
            continue
        if route['public_key'] in unmanaged_keys or any(ipaddress.ip_address(route['tunnel_ip']) in net for net in unmanaged_ips):
            raise ValueError('Managed peer collides with existing unmanaged peer')
        output += f"\n[Peer]\nPublicKey = {route['public_key']}\nAllowedIPs = {route['tunnel_ip']}/32\n"
    return output
