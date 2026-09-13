#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите: sudo ./scripts/install.sh [пользователь рабочего стола]" >&2
  exit 1
fi

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
KIOSK_USER=${1:-${SUDO_USER:-pi}}
KIOSK_HOME=$(getent passwd "$KIOSK_USER" | cut -d: -f6)
API_URL=${GBOU_API_BASE:-https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1}
UPDATE_URL=${GBOU_KIOSK_UPDATE_BASE:-https://gbousecurity.ru/kiosk}

if [ -z "$KIOSK_HOME" ] || [ ! -d "$KIOSK_HOME" ]; then
  echo "Не найден домашний каталог пользователя $KIOSK_USER" >&2
  exit 1
fi

install -d -m 0755 /opt/gbou-kiosk
install -d -m 0755 /var/lib/gbou-kiosk/web
install -m 0755 "$SOURCE_DIR/server.py" /opt/gbou-kiosk/server.py
for asset in index.html app.css app.js version.js; do
  if [ ! -f "/var/lib/gbou-kiosk/web/$asset" ]; then
    install -m 0644 "$SOURCE_DIR/web/$asset" "/var/lib/gbou-kiosk/web/$asset"
  fi
done
install -m 0755 "$SOURCE_DIR/scripts/chromium-kiosk.sh" /usr/local/bin/gbou-kiosk-browser
install -m 0644 "$SOURCE_DIR/systemd/gbou-kiosk.service" /etc/systemd/system/gbou-kiosk.service

printf 'GBOU_API_BASE=%s\nGBOU_KIOSK_UPDATE_BASE=%s\nGBOU_KIOSK_UPDATE_INTERVAL_SECONDS=300\nGBOU_KIOSK_DATA_ROOT=/var/lib/gbou-kiosk\nGBOU_KIOSK_HOST=127.0.0.1\nGBOU_KIOSK_PORT=8765\n' "$API_URL" "$UPDATE_URL" > /etc/gbou-kiosk.conf
chmod 0600 /etc/gbou-kiosk.conf

install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0755 "$KIOSK_HOME/.config/autostart"
cat > "$KIOSK_HOME/.config/autostart/gbou-kiosk.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=GBOU Guard Kiosk
Exec=/usr/local/bin/gbou-kiosk-browser
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/.config/autostart/gbou-kiosk.desktop"

systemctl daemon-reload
systemctl enable --now NetworkManager.service
systemctl enable --now gbou-kiosk.service

echo "Установлено. Перезагрузите Raspberry Pi: sudo reboot"
