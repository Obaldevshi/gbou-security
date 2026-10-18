"""Import a fresh frozen-source snapshot into a NEW, isolated school database."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
from unittest.mock import patch

from dotenv import load_dotenv


def normalized(value):
    return value.replace(tzinfo=None).isoformat() if isinstance(value, datetime) else value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--not-before', required=True)
    args = parser.parse_args()
    directory = Path('/var/lib/gbou-local/migration')
    assert args.source.parent == directory
    blob = args.source.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == args.sha256
    header = json.loads(blob)['header']
    created = datetime.fromisoformat(header['created_at'])
    assert created >= datetime.fromisoformat(args.not_before), 'Stale export is forbidden'
    target = directory / f'final-school2-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.sqlite3'
    assert not target.exists()
    os.chdir('/opt/gbou-local-api')
    load_dotenv('/etc/gbou-local/api.env', override=True)
    os.environ.update(DATABASE_URL=f'sqlite:///{target}', GBOU_SCHOOL_ID='2',
                      GBOU_CLOUD_API_BASE='https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1',
                      GBOU_NODE_TOKEN_FILE='/etc/gbou-local/node.token')
    sys.path.insert(0, '/opt/gbou-local-api')
    from sqlalchemy import select
    from scripts import local_node, school_transfer
    from scripts.node_config import sync
    from app.config.database import engine, SessionLocal
    from app.config.settings import settings
    from app.core.security import create_access_token
    from app.models.user import User
    from app.main import app
    from fastapi.testclient import TestClient
    assert settings.deployment_mode == 'local'
    assert local_node._sqlite_path() == target
    document = school_transfer.open_envelope(
        blob, (directory / 'receiver.pem').read_bytes(), 2)
    expected = {name: len(rows) for name, rows in document['rows'].items()}
    local_node.import_document(document)
    with engine.connect() as db:
        for name in local_node.ORDER:
            table = local_node.Base.metadata.tables[name]
            actual = list(db.execute(select(table).order_by(table.c.id)))
            assert len(actual) == expected[name]
            for original, row in zip(document['rows'][name], actual):
                decoded = local_node._decode_row(table, original)
                assert all(normalized(row._mapping[k]) == normalized(v)
                           for k, v in decoded.items()), f'Field mismatch: {name}'
    sync()
    from app.services.exit_request_service import ExitRequestService
    role_checks = {}
    # Queue GETs normally expire old requests. Permission verification must be
    # read-only until cutover; production expiry remains enabled after startup.
    with patch.object(ExitRequestService, '_expire_overdue', return_value=None), TestClient(app) as client, SessionLocal() as db:
        for role, paths, denied in (
            ('teacher', ('/api/v1/teacher/classes', '/api/v1/teacher/exit-requests'), '/api/v1/school/teachers'),
            ('guard', ('/api/v1/guard/exit-requests', '/api/v1/guard/exit-requests/history'), '/api/v1/teacher/classes'),
            ('school_admin', ('/api/v1/school/classes', '/api/v1/school/teachers'), '/api/v1/system/schools'),
        ):
            user = db.query(User).filter(User.school_id == 2, User.role == role,
                                        User.is_active.is_(True)).order_by(User.must_change_password.asc()).first()
            assert user is not None, f'Missing role: {role}'
            auth = {'Authorization': 'Bearer ' + create_access_token(user.id)}
            for path in paths:
                result = client.get(path, headers=auth)
                assert result.status_code == (403 if user.must_change_password else 200)
                if user.must_change_password:
                    assert result.json()['code'] == 'password_change_required'
            assert client.get(denied, headers=auth).status_code in {403, 404}
            role_checks[role] = 'password_change_required' if user.must_change_password else 'ready'
        assert client.get('/api/v1/guard/exit-requests').status_code == 401
        assert client.get('/api/v1/system/schools').status_code == 404
    with engine.connect() as db:
        for name in local_node.ORDER:
            table = local_node.Base.metadata.tables[name]
            actual = list(db.execute(select(table).order_by(table.c.id)))
            assert len(actual) == expected[name]
            for original, row in zip(document['rows'][name], actual):
                decoded = local_node._decode_row(table, original)
                assert all(normalized(row._mapping[k]) == normalized(v)
                           for k, v in decoded.items()), f'Post-verification mismatch: {name}'
    engine.dispose()
    with closing(sqlite3.connect(target)) as db:
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert not db.execute('PRAGMA foreign_key_check').fetchall()
        assert {n: db.execute(f'SELECT count(*) FROM {n}').fetchone()[0]
                for n in expected} == expected
    usb = Path('/mnt/gbou-backup')
    assert usb.is_mount() and usb.stat().st_dev != target.stat().st_dev
    passphrase = Path('/etc/gbou-local/backup.passphrase').read_text().strip()
    output = usb / f'final-school2-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.gbou'
    restored = target.with_name(target.stem + '-usb-restore.sqlite3')
    with tempfile.TemporaryDirectory(prefix='final-backup-', dir=directory) as temporary:
        snapshot = Path(temporary) / 'snapshot.sqlite3'
        with closing(sqlite3.connect(f'file:{target}?mode=ro', uri=True)) as src:
            with closing(sqlite3.connect(snapshot)) as copy:
                src.backup(copy)
        local_node._encrypt_file(snapshot, output, passphrase)
        local_node._verify_encrypted_file(output, passphrase)
        local_node._decrypt_file(output, restored, passphrase)
    with closing(sqlite3.connect(f'file:{target}?mode=ro', uri=True)) as src:
        with closing(sqlite3.connect(f'file:{restored}?mode=ro', uri=True)) as copy:
            assert copy.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
            assert not copy.execute('PRAGMA foreign_key_check').fetchall()
            assert list(src.iterdump()) == list(copy.iterdump())
    manifest = {'school_id': 2, 'database': str(target), 'source_sha256': args.sha256,
                'export_created_at': header['created_at'], 'counts': expected,
                'all_exported_fields_match': True, 'role_checks': role_checks,
                'usb_archive': str(output), 'usb_restored_database': str(restored),
                'usb_restore_all_rows_match': True, 'canonical_untouched': True}
    local_node._write_private(target.with_suffix('.verified.json'), json.dumps(manifest).encode())
    print(json.dumps(manifest))


if __name__ == '__main__':
    main()
