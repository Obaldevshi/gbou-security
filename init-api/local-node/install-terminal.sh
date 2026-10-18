#!/bin/sh
# Fresh CHILD only. Never install the school API or copy a school database.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run: sudo sh ./install-terminal.sh "$USER"'; exit 1; }
terminal_user=${1:-${SUDO_USER:-}}
[ -n "$terminal_user" ] && [ "$terminal_user" != root ] || { echo 'Specify the desktop user, not root'; exit 1; }
getent passwd "$terminal_user" >/dev/null || { echo 'Desktop user not found'; exit 1; }
for existing in /etc/gbou-device/device.json /var/lib/gbou-local/school.sqlite3 /etc/wireguard/gbou-wg.conf /etc/gbou-kiosk.conf; do
  [ ! -e "$existing" ] || { echo 'Existing installation found; refusing. Do not delete its files. Ask the operator to inspect it.'; exit 1; }
done
if systemctl is-active --quiet gbou-local-api; then
  echo 'A school API is running here. Never install a child on the main Raspberry.'
  exit 1
fi
terminal_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -f "$terminal_source/init-kiosk/server.py" ] || { echo 'Unpack the complete terminal archive first'; exit 1; }
[ -f "$terminal_source/local-node/install-pairing.sh" ] || { echo 'Pairing package missing'; exit 1; }
apt-get update
apt-get install -y --no-install-recommends python3 network-manager wireguard-tools
if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends chromium
fi
# No central school-login fallback before QR approval. No credentials here.
GBOU_API_BASE=https://unconfigured.invalid/api/v1 sh "$terminal_source/init-kiosk/scripts/install.sh" "$terminal_user"
sh "$terminal_source/local-node/install-pairing.sh"
echo 'Installed CHILD setup. No school database/API/tunnel was installed.'
echo 'On this Raspberry open http://127.0.0.1:8765 and choose QR setup.'
echo 'Select CHILD terminal on your phone. Do not select or activate PRIMARY.'
echo 'Reboot manually only after saving your work; Wi-Fi credentials were not edited.'
