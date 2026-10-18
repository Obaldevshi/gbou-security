#!/bin/sh
# Fresh devices only. This does not enroll/replace a working school server.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run with sudo'; exit 1; }
for existing in /etc/gbou-device/device.json /var/lib/gbou-local/school.sqlite3 /etc/wireguard/gbou-wg.conf; do
  [ ! -e "$existing" ] || { echo 'Existing enrollment/server found; refusing automatic replacement'; exit 1; }
done
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
apt-get update
apt-get install -y --no-install-recommends python3 wireguard-tools
install -d -m 700 /etc/gbou-device
install -d -m 755 /opt/gbou-device-setup
for script in pairing_agent.py device_enroll.py configure_terminal.py finish_terminal.py device_heartbeat.py; do
  install -m 755 "$source_dir/$script" "/opt/gbou-device-setup/$script"
done
install -m 644 "$source_dir/systemd/gbou-device-setup.service" /etc/systemd/system/gbou-device-setup.service
install -m 644 "$source_dir/systemd/gbou-device-terminal.service" /etc/systemd/system/gbou-device-terminal.service
install -m 644 "$source_dir/systemd/gbou-device-terminal.timer" /etc/systemd/system/gbou-device-terminal.timer
install -m 644 "$source_dir/systemd/gbou-device-heartbeat.service" /etc/systemd/system/gbou-device-heartbeat.service
install -m 644 "$source_dir/systemd/gbou-device-heartbeat.timer" /etc/systemd/system/gbou-device-heartbeat.timer
systemctl daemon-reload
systemctl enable --now gbou-device-setup
systemctl enable --now gbou-device-terminal.timer
systemctl enable --now gbou-device-heartbeat.timer
echo 'QR setup ready on this Raspberry: http://127.0.0.1:8766/'
