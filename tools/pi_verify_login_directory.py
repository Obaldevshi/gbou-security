"""Read-only post-release lookup/CORS probe; no source identifiers printed."""
import json
import os
import sys
from pathlib import Path

ROOT = Path('/opt/gbou-local-api')
os.chdir(ROOT)
sys.path.insert(0, str(ROOT))
from dotenv import load_dotenv
load_dotenv('/etc/gbou-local/api.env', override=True)
import httpx
from app.config.database import SessionLocal
from scripts.login_directory import local_digests


def main():
    base = os.environ['GBOU_CLOUD_API_BASE'].rstrip('/')
    school_id = int(os.environ['GBOU_SCHOOL_ID'])
    school = 'https://school-2036.gbousecurity.ru'
    assert school_id == 2
    with SessionLocal() as db:
        samples = local_digests(db, school_id)[:3]
    assert len(samples) == 3
    with httpx.Client(timeout=30, follow_redirects=False, trust_env=False) as client:
        for digest in samples:
            response = client.post(base + '/login-directory/resolve', json={'login_digest': digest})
            assert response.status_code == 200
            assert response.json() == {'school_id': school_id, 'origin': school}
            assert 'no-store' in response.headers.get('cache-control', '')
        for path, status in [('/ready', 200), ('/api/v1/teacher/classes', 401), ('/api/v1/node/config', 404)]:
            assert client.get(school + path).status_code == status
        response = client.options(school + '/api/v1/auth/login', headers={
            'Origin': 'https://gbousecurity.ru', 'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'content-type',
        })
        assert response.status_code == 200
        assert response.headers.get('access-control-allow-origin') == 'https://gbousecurity.ru'
        denied = client.options(school + '/api/v1/auth/login', headers={
            'Origin': 'https://untrusted.invalid', 'Access-Control-Request-Method': 'POST',
        })
        assert denied.headers.get('access-control-allow-origin') is None
    print(json.dumps({'lookup_samples_verified': 3, 'school_scope_and_address': True,
                      'no_store': True, 'school_statuses': '200/401/404',
                      'exact_central_cors': True, 'untrusted_origin_denied': True,
                      'password_or_business_records_changed': False}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('L14 verification failed (' + type(error).__name__ + ')') from None
