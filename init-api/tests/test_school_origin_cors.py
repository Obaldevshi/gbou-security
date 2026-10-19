"""Central browser operations from an owned school subdomain; no DB or real login."""
import os
os.environ.setdefault('DATABASE_URL', 'sqlite://')
os.environ.setdefault('SECRET_KEY', 'test-cors-secret-with-more-than-thirty-two-characters')
os.environ.setdefault('ALGORITHM', 'HS256')

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from app.config.settings import Settings


def client_for(mode='cloud', enabled=True, domain='gbousecurity.ru'):
    config = Settings(database_url='sqlite:///:memory:', _env_file=None,
        secret_key='cors-test-only-key-with-more-than-thirty-two-characters',
        algorithm='HS256', deployment_mode=mode, school_devices_enabled=enabled,
        school_domain=domain, cors_origins='', cors_origin_regex=r'^$')
    app = FastAPI()
    app.add_middleware(CORSMiddleware, allow_origin_regex=config.effective_cors_origin_regex,
        allow_methods=['POST'], allow_headers=['authorization', 'content-type'], allow_credentials=True)
    return TestClient(app)


def preflight(client, origin):
    return client.options('/api/v1/auth/account-deletion-session', headers={
        'Origin': origin, 'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type'})


def test_owned_https_school_origin_is_allowed_but_not_lookalikes():
    with client_for() as client:
        for origin in ('https://school-2036.gbousecurity.ru', 'https://s236.gbousecurity.ru',
                       'https://2036.gbousecurity.ru'):
            response = preflight(client, origin)
            assert response.status_code == 200
            assert response.headers['access-control-allow-origin'] == origin
        for origin in ('http://s236.gbousecurity.ru', 'https://s236.gbousecurity.ru.evil.example',
                       'https://evil.example', 'https://a.b.gbousecurity.ru',
                       'https://s236.gbousecurity.ru:8080', 'https://-bad.gbousecurity.ru', 'null'):
            assert preflight(client, origin).status_code == 400


def test_local_disabled_and_invalid_domain_remain_closed():
    for arguments in ({'mode': 'local'}, {'enabled': False}, {'domain': '.*'},
                      {'domain': 'gbousecurity.ru|evil.example'}):
        with client_for(**arguments) as client:
            assert preflight(client, 'https://s236.gbousecurity.ru').status_code == 400
