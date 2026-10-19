"""Read-only, encrypted logical snapshot before additive control-plane migration.

Remote mode emits encrypted chunks only. Local verification never writes plaintext.
This is a transaction-consistent data snapshot, not a tested PostgreSQL restore.
"""
import argparse
import base64
from datetime import date, datetime, timezone
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import uuid
import zlib

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

FORMAT = 'GBOU-CENTRAL-LOGICAL-1'
ROOT = Path(__file__).resolve().parents[1] if '__file__' in globals() else None


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def typed(value):
    if isinstance(value, (datetime, date)):
        return {'$datetime': value.isoformat()}
    if isinstance(value, (bytes, memoryview)):
        return {'$bytes': base64.b64encode(value).decode()}
    if isinstance(value, (Decimal, uuid.UUID)):
        return {'$' + type(value).__name__: str(value)}
    raise TypeError(type(value).__name__)


def remote(public_key):
    from sqlalchemy import MetaData, select
    from app.config.database import engine
    assert engine.dialect.name == 'postgresql'
    with engine.connect().execution_options(isolation_level='REPEATABLE READ') as connection:
        with connection.begin():
            connection.exec_driver_sql('SET TRANSACTION READ ONLY')
            metadata = MetaData()
            metadata.reflect(bind=connection)
            tables, schemas = {}, {}
            for table in metadata.sorted_tables:
                tables[table.name] = [dict(row) for row in connection.execute(select(table)).mappings()]
                schemas[table.name] = [{'name': c.name, 'type': str(c.type), 'nullable': c.nullable,
                                       'primary_key': c.primary_key} for c in table.columns]
            revision = tables['alembic_version'][0]['version_num']
            assert revision == '015_login_directory'
            endpoint = [r for r in tables['school_endpoints'] if r['school_id'] == 2]
            assert len(endpoint) == 1 and endpoint[0]['generation'] == 3
            device = [r for r in tables['school_devices'] if r['device_id'] == endpoint[0]['primary_device_id']]
            assert len(device) == 1 and device[0]['building_id'] == 1 and device[0]['state'] == 'active'
            payload = json.dumps({'format': FORMAT, 'tables': tables, 'schemas': schemas},
                                 sort_keys=True, separators=(',', ':'), default=typed).encode()
    header = {'format': FORMAT, 'created_at': datetime.now(timezone.utc).isoformat(),
              'revision': revision, 'rows': {t: len(rows) for t, rows in tables.items()},
              'plaintext_sha256': hashlib.sha256(payload).hexdigest()}
    key, nonce = os.urandom(32), os.urandom(12)
    receiver = serialization.load_der_public_key(base64.b64decode(public_key, validate=True))
    wrapped = receiver.encrypt(key, padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),
                                                algorithm=hashes.SHA256(), label=FORMAT.encode()))
    encrypted = AESGCM(key).encrypt(nonce, zlib.compress(payload, 9), canonical(header))
    blob = canonical({'header': header, 'wrapped_key': base64.b64encode(wrapped).decode(),
                      'nonce': base64.b64encode(nonce).decode(),
                      'ciphertext': base64.b64encode(encrypted).decode()})
    transport = base64.b64encode(blob).decode()
    chunks = [transport[i:i+3600] for i in range(0, len(transport), 3600)]
    for index, chunk in enumerate(chunks):
        print('\033[2J\033[H', end='')
        print(f'GBOU_CHUNK_BEGIN:{index}:{len(chunks)}')
        for offset in range(0, len(chunk), 120):
            print(chunk[offset:offset+120])
        print(f'GBOU_CHUNK_END:{index}', flush=True)
        input()
    print('GBOU_BACKUP_STREAM_COMPLETE', flush=True)


def prepare():
    folder = ROOT / 'artifacts/private-release-1.8.0-14'
    assert folder.is_dir() and not (folder/'receiver.pem').exists()
    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    (folder/'receiver.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    (folder/'receiver-public.der').write_bytes(key.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo))
    print(json.dumps({'receiver_prepared': True, 'private_directory': str(folder)}))


def verify():
    folder = ROOT / 'artifacts/private-release-1.8.0-14'
    blob = (folder/'central-before-016.gbou').read_bytes()
    document = json.loads(blob)
    header = document['header']
    assert header['format'] == FORMAT and header['revision'] == '015_login_directory'
    private = serialization.load_pem_private_key((folder/'receiver.pem').read_bytes(), password=None)
    key = private.decrypt(base64.b64decode(document['wrapped_key'], validate=True),
        padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=FORMAT.encode()))
    compressed = AESGCM(key).decrypt(base64.b64decode(document['nonce'], validate=True),
        base64.b64decode(document['ciphertext'], validate=True), canonical(header))
    payload = zlib.decompress(compressed)
    assert hashlib.sha256(payload).hexdigest() == header['plaintext_sha256']
    restored = json.loads(payload)
    assert restored['format'] == FORMAT
    assert {t: len(rows) for t, rows in restored['tables'].items()} == header['rows']
    result = {'encrypted_backup_verified': True, 'revision': header['revision'], 'rows': header['rows'],
              'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest(),
              'plaintext_written_to_disk': False, 'postgresql_restore_tested': False}
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'remote', 'verify'])
    parser.add_argument('--public-key')
    args = parser.parse_args()
    if args.mode == 'remote':
        remote(args.public_key)
    elif args.mode == 'prepare':
        prepare()
    else:
        verify()
