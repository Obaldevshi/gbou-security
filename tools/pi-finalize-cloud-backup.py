"""Rewrap the cloud dump for USB recovery independent of the SD RSA key."""
import argparse
import base64
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--sha256', required=True)
    args = parser.parse_args()
    assert args.source.parent == Path('/var/lib/gbou-local/migration')
    blob = args.source.read_bytes()
    assert len(blob) <= 32 * 1024 * 1024
    assert hashlib.sha256(blob).hexdigest() == args.sha256
    document = json.loads(blob)
    header = document['header']
    assert header['format'] == 'GBOU-PG-BACKUP-1'
    assert header['pg_restore_validated'] is True
    private = Path('/var/lib/gbou-local/migration/receiver.pem')
    assert private.stat().st_mode & 0o077 == 0
    rsa_key = serialization.load_pem_private_key(private.read_bytes(), password=None)
    key = rsa_key.decrypt(base64.b64decode(document['wrapped_key'], validate=True),
                          padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),
                                       algorithm=hashes.SHA256(), label=b'GBOU-PG-BACKUP-1'))
    aad = json.dumps(header, sort_keys=True, separators=(',', ':')).encode()
    dump = AESGCM(key).decrypt(base64.b64decode(document['nonce'], validate=True),
                               base64.b64decode(document['ciphertext'], validate=True), aad)
    assert dump.startswith(b'PGDMP') and len(dump) == header['bytes']
    assert hashlib.sha256(dump).hexdigest() == header['plaintext_sha256']
    usb = Path('/mnt/gbou-backup')
    assert usb.is_mount() and usb.stat().st_dev != private.stat().st_dev
    os.chdir('/opt/gbou-local-api')
    load_dotenv('/etc/gbou-local/api.env', override=True)
    sys.path.insert(0, '/opt/gbou-local-api')
    from scripts import local_node
    passphrase = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
    assert len(passphrase) >= 16
    output = usb / f'cloud-precutover-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.pgdump.gbou'
    local_node._write_private(output, local_node._seal(dump, passphrase))
    local_node._verify_encrypted_file(output, passphrase)
    restored = local_node._open(output.read_bytes(), passphrase)
    assert restored == dump
    local_node._write_private(output.with_suffix(output.suffix + '.manifest.json'),
                              json.dumps(header, sort_keys=True).encode())
    print(json.dumps({'cloud_backup': str(output), 'dump_bytes': len(dump),
                      'usb_decrypt_roundtrip': True, 'sha256_match': True,
                      'postgresql_format_checked_on_source': True,
                      'postgresql_database_restore_tested': False}))


if __name__ == '__main__':
    main()
