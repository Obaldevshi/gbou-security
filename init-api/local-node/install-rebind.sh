#!/bin/sh
# Explicit one-time controller installation, NEVER starts a rebind operation.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run with sudo'; exit 1; }
kiosk_user=${1:?Pass the existing kiosk Linux user}
id "$kiosk_user" >/dev/null
[ "$(id -u "$kiosk_user")" -ge 1000 ] || { echo 'Use the existing non-root kiosk user'; exit 1; }
case "$kiosk_user" in *[!a-zA-Z0-9_-]*|'') echo 'Invalid kiosk user'; exit 1;; esac
[ -f /etc/gbou-device/device.json ] || { echo 'Enroll this device first'; exit 1; }
[ -f /opt/gbou-kiosk/server.py ] || { echo 'Install the existing kiosk first'; exit 1; }
[ ! -L /opt/gbou-device-setup ] || { echo 'Unexpected setup directory link'; exit 1; }
[ ! -e /var/lib/gbou-reprovision/in-progress ] || { echo 'Finish the existing rebind first'; exit 1; }
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# This path only updates an inactive/setup controller, never a running job.
if systemctl is-active --quiet gbou-device-rebind.service; then
  echo 'Stop the idle controller deliberately before replacing its code'; exit 1
fi
# Preserve private state/config. Install only trusted repository program files.
install -d -m 755 /opt/gbou-device-setup
for script in rebind_control.py rebind_primary.py pairing_agent.py device_enroll.py configure_terminal.py finish_terminal.py; do
  install -m 755 "$source_dir/$script" "/opt/gbou-device-setup/$script"
done
install -m 644 "$source_dir/systemd/gbou-device-setup.service" /opt/gbou-device-setup/gbou-device-setup.service
# Do not enable fresh setup on a working writer. Its existing Conditions remain.
if [ ! -f /etc/systemd/system/gbou-device-setup.service ]; then
  install -m 644 "$source_dir/systemd/gbou-device-setup.service" /etc/systemd/system/gbou-device-setup.service
fi
if [ -f /etc/gbou-device-rebind.conf ]; then
  grep -qx "GBOU_KIOSK_USER=$kiosk_user" /etc/gbou-device-rebind.conf || { echo 'Existing user configuration differs; inspect it first'; exit 1; }
else
  (umask 077; printf 'GBOU_KIOSK_USER=%s\n' "$kiosk_user" > /etc/gbou-device-rebind.conf)
fi
install -m 644 "$source_dir/systemd/gbou-device-rebind.service" /etc/systemd/system/gbou-device-rebind.service
systemctl daemon-reload
systemctl enable --now gbou-device-rebind.service
echo 'Controller installed; no rebind, database or network operation performed.'
