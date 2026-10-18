"""Verify node credentials and sync on an isolated DB, never the live one."""
import json
import os
import sqlite3
import sys
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv


def main():
    os.chdir('/opt/gbou-local-api')
    load_dotenv('/etc/gbou-local/api.env', override=True)
    os.environ.update(
        GBOU_SCHOOL_ID='2',
        GBOU_CLOUD_API_BASE='https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1',
        GBOU_NODE_TOKEN_FILE='/etc/gbou-local/node.token',
    )
    source = Path('/var/lib/gbou-local/migration/stage-school2.sqlite3')
    target = source.with_name(f'sync-check-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.sqlite3')
    assert not target.exists()
    descriptor = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    os.close(descriptor)
    with closing(sqlite3.connect(f'file:{source}?mode=ro', uri=True)) as db:
        with closing(sqlite3.connect(target)) as copy:
            db.backup(copy)
    os.environ['DATABASE_URL'] = f'sqlite:///{target}'
    sys.path.insert(0, '/opt/gbou-local-api')
    import httpx
    from scripts.node_config import sync, _read_token
    from app.schemas.node_config import NodeConfigEnvelope
    token = _read_token(Path('/etc/gbou-local/node.token'))
    url = os.environ['GBOU_CLOUD_API_BASE'] + '/node/config'
    with httpx.Client(timeout=20, follow_redirects=False, trust_env=False) as client:
        result = client.get(url, headers={'X-School-Node-Token': token})
        assert result.status_code == 200, f'Node configuration HTTP {result.status_code}'
        assert result.headers.get('cache-control') == 'no-store'
        data = result.json()['data']
        assert set(data) == {'school', 'buildings', 'school_admins'}
        config = NodeConfigEnvelope.model_validate(result.json()).data
        assert config.school.id == 2
        assert all(row.school_id == 2 for row in config.buildings + config.school_admins)
        assert client.get(url).status_code == 401
        assert client.get(url, headers={'X-School-Node-Token': 'invalid-key'}).status_code == 401
    with closing(sqlite3.connect(target)) as db:
        before = {table: db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
                  for table in ('students', 'school_classes', 'exit_requests', 'users')}
    sync()
    sync()
    with closing(sqlite3.connect(target)) as db:
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert not db.execute('PRAGMA foreign_key_check').fetchall()
        after = {table: db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
                 for table in before}
        assert before == after, 'Sync unexpectedly changed school record counts'
        assert db.execute("SELECT value FROM local_meta WHERE key='last_config_sync'").fetchone()
    print(json.dumps({'scope_verified': True, 'idempotent_sync': True,
                      'canonical_untouched': True, 'buildings': len(config.buildings),
                      'school_admins': len(config.school_admins), 'test_database': str(target)}))


if __name__ == '__main__':
    main()
