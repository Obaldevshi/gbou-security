#!/bin/sh
# Add the Pi's current RFC1918 IPv4 to its existing TLS site. No port forwarding,
# no trust-store changes, no passwords, and no database/kiosk changes.
set -eu
umask 022
[ "$(id -u)" -eq 0 ] || { echo 'Запустите через sudo' >&2; exit 1; }
ADDRESS=${1:?Укажите текущий локальный IPv4 Raspberry}
CANDIDATE=$(mktemp /etc/caddy/Caddyfile.gbou-candidate.XXXXXXXX)
trap 'rm -f "$CANDIDATE"' EXIT HUP INT TERM
python3 - "$ADDRESS" "$CANDIDATE" <<'PY'
import ipaddress
import json
from pathlib import Path
import subprocess
import sys

address = ipaddress.IPv4Address(sys.argv[1])
private = ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
if not any(address in ipaddress.IPv4Network(network) for network in private):
    raise SystemExit('Разрешён только внутренний IPv4 школы')
interfaces = json.loads(subprocess.check_output(['ip', '-j', 'address', 'show']))
if str(address) not in {entry.get('local') for interface in interfaces for entry in interface['addr_info']}:
    raise SystemExit('Этот адрес сейчас не принадлежит Raspberry')
source = Path('/etc/caddy/Caddyfile').read_text()
lines = source.splitlines()
headers = [index for index, line in enumerate(lines)
           if line.startswith('gbousecurity.local') and line.rstrip().endswith('{')]
if len(headers) != 1:
    raise SystemExit('Не найдена однозначная конфигурация школьного сайта; файл не изменён')
lines[headers[0]] = f'gbousecurity.local, {address} {{'
Path(sys.argv[2]).write_text('\n'.join(lines) + '\n')
PY
caddy validate --config "$CANDIDATE" --adapter caddyfile
BACKUP=$(mktemp /etc/caddy/Caddyfile.before-gbou-lan.XXXXXXXX)
cp -p /etc/caddy/Caddyfile "$BACKUP"
install -m 0644 "$CANDIDATE" /etc/caddy/Caddyfile
if ! systemctl reload caddy; then
    install -m 0644 "$BACKUP" /etc/caddy/Caddyfile
    systemctl reload caddy
    echo 'Перезагрузка не прошла; прежняя конфигурация восстановлена' >&2
    exit 1
fi
echo "HTTPS: https://gbousecurity.local или https://$ADDRESS"
echo "Резервная копия Caddy: $BACKUP"
echo 'На телефоне требуется доверенный сертификат школы. Проверка TLS не отключается.'
echo 'При смене сети сначала закрепите новый адрес в школьном DHCP и повторите настройку.'
