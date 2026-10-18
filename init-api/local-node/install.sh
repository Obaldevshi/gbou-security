#!/bin/sh
set -eu
umask 022

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите через sudo" >&2
  exit 1
fi
python3 -c 'import sys; assert sys.version_info >= (3, 11), "Нужен Python 3.11 или новее"'

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "$SOURCE_DIR/app/main.py" ]; then
  echo "Запустите из полного каталога init-api" >&2
  exit 1
fi

apt-get update
apt-get install -y python3-venv python3-cryptography
if ! id gbou-local >/dev/null 2>&1; then
  useradd --system --home /var/lib/gbou-local --shell /usr/sbin/nologin gbou-local
fi
install -d -o gbou-local -g gbou-local -m 0700 /var/lib/gbou-local
install -d -o gbou-local -g gbou-local -m 0700 /etc/gbou-local
install -d -m 0755 /opt/gbou-local-api
install -d -o gbou-local -g gbou-local -m 0700 /mnt/gbou-backup
cp -R "$SOURCE_DIR/app" "$SOURCE_DIR/scripts" /opt/gbou-local-api/
install -m 0644 "$SOURCE_DIR/local-node/requirements-local.txt" /opt/gbou-local-api/requirements.txt
python3 -m venv --system-site-packages /opt/gbou-local-api/.venv
# Fail clearly if no ARM wheel exists, instead of compiling Rust on a 1GB Pi.
/opt/gbou-local-api/.venv/bin/pip install --disable-pip-version-check --prefer-binary --only-binary=bcrypt,pydantic-core -c "$SOURCE_DIR/local-node/constraints-tested.txt" -r /opt/gbou-local-api/requirements.txt
# Archives unpacked under a private SSH umask may contain 0700 code folders.
# Only program files live here; secrets remain separately under /etc/gbou-local.
chmod -R a+rX /opt/gbou-local-api

if [ ! -e /etc/gbou-local/api.env ]; then
  API_SECRET=$(/opt/gbou-local-api/.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')
  printf 'DATABASE_URL=sqlite:////var/lib/gbou-local/school.sqlite3\nDEPLOYMENT_MODE=local\nSECRET_KEY=%s\nALGORITHM=HS256\nCORS_ORIGINS=\nCORS_ORIGIN_REGEX=^$\nGBOU_CLOUD_API_BASE=https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1\nGBOU_NODE_TOKEN_FILE=/etc/gbou-local/node.token\nGBOU_SCHOOL_ID=0\n' "$API_SECRET" > /etc/gbou-local/api.env
  chown gbou-local:gbou-local /etc/gbou-local/api.env
  chmod 0600 /etc/gbou-local/api.env
fi

if [ ! -e /etc/gbou-local/backup.passphrase ]; then
  /opt/gbou-local-api/.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))' > /etc/gbou-local/backup.passphrase
  chown gbou-local:gbou-local /etc/gbou-local/backup.passphrase
  chmod 0600 /etc/gbou-local/backup.passphrase
fi

install -m 0644 "$SOURCE_DIR/local-node/gbou-local-api.service" /etc/systemd/system/
install -m 0644 "$SOURCE_DIR/local-node/gbou-local-backup.service" /etc/systemd/system/
install -m 0644 "$SOURCE_DIR/local-node/gbou-local-backup.timer" /etc/systemd/system/
install -m 0644 "$SOURCE_DIR/local-node/gbou-local-sync.service" /etc/systemd/system/
install -m 0644 "$SOURCE_DIR/local-node/gbou-local-sync.timer" /etc/systemd/system/
cd /opt/gbou-local-api
su -s /bin/sh gbou-local -c 'set -a; . /etc/gbou-local/api.env; set +a; /opt/gbou-local-api/.venv/bin/python -m scripts.local_node init'
systemctl daemon-reload
systemctl enable --now gbou-local-api.service gbou-local-backup.timer
echo "Локальный API установлен на 127.0.0.1:8081. Синхронизация не включена до выдачи ключа узла."
echo "Перенос школы и USB-монтирование пока НЕ выполнены."
echo "Сохраните /etc/gbou-local/backup.passphrase отдельно от Raspberry, иначе при поломке SD USB-копии нельзя восстановить."
