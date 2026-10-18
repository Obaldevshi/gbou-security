#!/bin/sh
# Install only static school UI. Never copies databases, configs or private keys.
set -eu
umask 022
if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите через sudo" >&2
  exit 1
fi
WEB_SOURCE=${1:?Укажите каталог школьной web-сборки}
if [ ! -f "$WEB_SOURCE/index.html" ] || [ ! -f "$WEB_SOURCE/flutter_bootstrap.js" ]; then
  echo "Каталог не содержит готовую Flutter web-сборку" >&2
  exit 1
fi
if [ -f "$WEB_SOURCE/.env" ] || [ -f "$WEB_SOURCE/school.sqlite3" ]; then
  echo "В каталоге обнаружены недопустимые серверные данные" >&2
  exit 1
fi
apt-get update
apt-get install -y caddy avahi-daemon
install -d -m 0755 /var/www/gbou-local
# Preserve old files for now; versioned Flutter assets are not removed blindly.
cp -R "$WEB_SOURCE/." /var/www/gbou-local/
chown -R root:root /var/www/gbou-local
find /var/www/gbou-local -type d -exec chmod 0755 {} +
find /var/www/gbou-local -type f -exec chmod 0644 {} +
SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f /etc/caddy/Caddyfile ]; then
  cp -p /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.before-gbou-$(date +%Y%m%dT%H%M%S)"
fi
install -m 0644 "$SOURCE_DIR/Caddyfile.example" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable --now avahi-daemon caddy
systemctl reload caddy
echo "Школьный web установлен. Требуется имя устройства gbousecurity и доступ в школьной сети."
echo "Не открывайте порты Raspberry в публичный интернет."
echo "Доверие к локальному HTTPS настройте по инструкции CLIENTS.md."
