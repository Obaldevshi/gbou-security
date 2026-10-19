"""Private-node release checks. Never prints identities, tokens or database rows."""
from contextlib import closing
from pathlib import Path
import argparse
import hashlib
import json
import logging
import os
import sqlite3
import secrets
import sys
import tempfile

DB = Path('/var/lib/gbou-local/school.sqlite3')


def fingerprints(path):
    result = {}
    with closing(sqlite3.connect(f'file:{path}?mode=ro', uri=True)) as db:
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert db.execute('PRAGMA foreign_key_check').fetchone() is None
        tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
        for table in tables:
            assert table.replace('_', '').isalnum()
            columns = [r[1] for r in db.execute(f'PRAGMA table_info("{table}")')]
            # Only the explicitly additive field and operational metadata change.
            if table == 'local_meta':
                continue
            columns = [c for c in columns if not (table == 'users' and c == 'deleted_at')]
            selected = ','.join('"' + c + '"' for c in columns)
            rows = sorted(json.dumps(tuple(row), default=str, ensure_ascii=False)
                          for row in db.execute(f'SELECT {selected} FROM "{table}"'))
            result[table] = {'rows': len(rows), 'sha256': hashlib.sha256('\n'.join(rows).encode()).hexdigest()}
    return result


def migrate(path):
    with closing(sqlite3.connect(path, timeout=30)) as db:
        columns = {r[1] for r in db.execute('PRAGMA table_info(users)')}
        if 'deleted_at' not in columns:
            db.execute('ALTER TABLE users ADD COLUMN deleted_at DATETIME')
        db.commit()


def check_copy(source, program):
    from dotenv import load_dotenv
    load_dotenv('/etc/gbou-local/api.env', override=True)
    assert os.environ['DEPLOYMENT_MODE'] == 'local'
    assert os.environ['DATABASE_URL'] == 'sqlite:////var/lib/gbou-local/school.sqlite3'
    with tempfile.TemporaryDirectory(prefix='release-check-', dir=DB.parent) as temporary:
        target = Path(temporary) / 'offline.sqlite3'
        with closing(sqlite3.connect(f'file:{source}?mode=ro', uri=True)) as original:
            with closing(sqlite3.connect(target)) as copy:
                original.backup(copy)
        before = fingerprints(target)
        migrate(target)
        assert fingerprints(target) == before
        os.environ['DATABASE_URL'] = 'sqlite:///' + str(target)
        os.environ['SECRET_KEY'] = secrets.token_urlsafe(48)
        os.chdir(program)
        sys.path.insert(0, str(program))
        logging.disable(logging.CRITICAL)
        from fastapi.testclient import TestClient
        from app.main import app
        from app.config.database import SessionLocal, engine
        from app.core.security import create_access_token
        from app.models.user import User
        paths = {'teacher': '/api/v1/teacher/classes',
                 'guard': '/api/v1/guard/exit-requests',
                 'school_admin': '/api/v1/school/classes'}
        verified = []
        with TestClient(app) as client:
            assert client.get('/ready').status_code == 200
            assert client.get('/api/v1/users/deletion-info').status_code == 401
            with SessionLocal() as session:
                for role, path in paths.items():
                    user = session.query(User).filter(User.school_id == 2, User.role == role,
                        User.is_active.is_(True), User.must_change_password.is_(False), User.deleted_at.is_(None)).first()
                    assert user is not None
                    headers = {'Authorization': 'Bearer ' + create_access_token(user.id)}
                    assert client.get(path, headers=headers).status_code == 200, role
                    assert client.get('/api/v1/users/deletion-info', headers=headers).status_code == 200, role
                    verified.append(role)
            assert client.get('/api/v1/node/config').status_code == 404
        engine.dispose()
    print(json.dumps({'offline_copy_checks_passed': True, 'roles': verified,
                      'additive_migration_preserved_all_existing_fields': True}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--copy', action='store_true')
    parser.add_argument('--program', type=Path, default=Path('/opt/gbou-local-api'))
    args = parser.parse_args()
    if args.copy:
        check_copy(DB, args.program)
    else:
        with closing(sqlite3.connect(f'file:{DB}?mode=ro', uri=True)) as db:
            has_field = any(r[1] == 'deleted_at' for r in db.execute('PRAGMA table_info(users)'))
        print(json.dumps({'integrity': 'ok', 'tables': {t: r['rows'] for t, r in fingerprints(DB).items()},
                          'deleted_at_present': has_field}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'release_check_failed': type(error).__name__}), file=sys.stderr)
        raise SystemExit(1)
