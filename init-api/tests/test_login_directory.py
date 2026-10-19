"""Synthetic isolated routing tests. No network, production data or credentials."""
from datetime import timedelta
import hashlib

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import app.models
from app.models import Base, School, SchoolDevice, SchoolEndpoint, User, UserRole, SchoolBuilding
from app.models.login_directory import LoginDirectoryEntry
from app.config.settings import settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnauthorizedError, BaseError
from app.repositories.login_directory_repository import LoginDirectoryRepository
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.schemas.login_directory import DirectorySnapshot
from app.services.login_directory_service import LoginDirectoryService
from app.services.school_device_service import SchoolDeviceService, digest, utcnow
from scripts.login_directory import local_digests, login_digest


@pytest.fixture
def setup(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    monkeypatch.setattr(settings, 'school_devices_enabled', True)
    monkeypatch.setattr(settings, 'login_directory_enabled', True)
    monkeypatch.setattr(settings, 'login_directory_pepper', 'synthetic-separate-routing-pepper-' * 2)
    engine = create_engine('sqlite:///' + (tmp_path / 'directory.sqlite').as_posix(), connect_args={'check_same_thread': False})
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine, expire_on_commit=False)() as db:
        for i in (1, 2):
            db.add(School(id=i, full_name='Synthetic', short_name=str(i), address='Synthetic', is_active=True))
        db.flush()
        for i in (1, 2):
            db.add(SchoolDevice(school_id=i, device_id=f'primary-{i}', label='Synthetic', role='primary',
                               state='active', token_hash=digest(str(i) * 64), generation=1))
            db.add(SchoolEndpoint(school_id=i, slug=str(i), generation=1, primary_device_id=f'primary-{i}'))
        db.commit()
        manager = LoginDirectoryService(LoginDirectoryRepository(db), SchoolDeviceService(SchoolDeviceRepository(db)))
        yield db, manager
    engine.dispose()


def snapshot(*logins, generation=1):
    return DirectorySnapshot(generation=generation, login_digests=[login_digest(v) for v in logins])


def test_digest_matches_wire_contract():
    assert login_digest(' Teacher.Demo ') == hashlib.sha256(b'gbou-login-directory-v1:teacher.demo').hexdigest()
    assert login_digest(' Teacher.Demo ') == login_digest('teacher.demo')


def test_hmac_only_and_full_replacement(setup):
    db, manager = setup
    manager.replace('1' * 64, snapshot('teacher.demo', 'guard.demo', 'teacher.demo'))
    rows = db.query(LoginDirectoryEntry).all()
    assert len(rows) == 2
    assert manager.resolve(login_digest('teacher.demo')).origin == 'https://1.gbousecurity.ru'
    assert all(row.lookup_tag not in {login_digest('teacher.demo'), login_digest('guard.demo')} for row in rows)
    raw = str(db.execute(text('SELECT * FROM login_directory_entries')).all())
    assert 'teacher.demo' not in raw and 'guard.demo' not in raw and login_digest('teacher.demo') not in raw
    manager.replace('1' * 64, snapshot('new.demo'))
    with pytest.raises(NotFoundError): manager.resolve(login_digest('teacher.demo'))
    assert manager.resolve(login_digest('new.demo')).school_id == 1
    manager.replace('1' * 64, snapshot())
    assert db.query(LoginDirectoryEntry).count() == 0


def test_current_primary_only_and_generation_fence(setup):
    db, manager = setup
    with pytest.raises(UnauthorizedError): manager.replace('x' * 64, snapshot('teacher.demo'))
    with pytest.raises(ConflictError): manager.replace('1' * 64, snapshot('teacher.demo', generation=2))
    device = db.query(SchoolDevice).filter_by(device_id='primary-1').one()
    device.role = 'terminal'
    db.commit()
    with pytest.raises(ForbiddenError): manager.replace('1' * 64, snapshot('teacher.demo'))
    device.role, device.state = 'primary', 'pending'
    db.commit()
    with pytest.raises(ForbiddenError): manager.replace('1' * 64, snapshot('teacher.demo'))
    device.state = 'revoked'
    db.commit()
    with pytest.raises(UnauthorizedError): manager.replace('1' * 64, snapshot('teacher.demo'))
    assert db.query(LoginDirectoryEntry).count() == 0


def test_duplicate_fail_closed_and_school_scope(setup):
    db, manager = setup
    manager.replace('1' * 64, snapshot('duplicate.demo'))
    manager.replace('2' * 64, snapshot('duplicate.demo'))
    with pytest.raises(NotFoundError): manager.resolve(login_digest('duplicate.demo'))
    manager.replace('2' * 64, snapshot())
    assert manager.resolve(login_digest('duplicate.demo')).school_id == 1
    assert db.query(LoginDirectoryEntry).one().school_id == 1


@pytest.mark.parametrize('change', ['ttl', 'school', 'generation', 'revoked', 'owner'])
def test_stale_or_disabled_pointers_never_resolve(setup, change):
    db, manager = setup
    manager.replace('1' * 64, snapshot('teacher.demo'))
    if change == 'ttl': db.query(LoginDirectoryEntry).one().expires_at = utcnow() - timedelta(seconds=1)
    if change == 'school': db.get(School, 1).is_active = False
    if change == 'generation': db.query(SchoolEndpoint).filter_by(school_id=1).one().generation = 2
    if change == 'revoked': db.query(SchoolDevice).filter_by(device_id='primary-1').one().state = 'revoked'
    if change == 'owner':
        db.query(SchoolEndpoint).filter_by(school_id=2).one().primary_device_id = None
        db.flush()
        db.query(SchoolEndpoint).filter_by(school_id=1).one().primary_device_id = 'primary-2'
    db.commit()
    with pytest.raises(NotFoundError): manager.resolve(login_digest('teacher.demo'))


def test_pepper_rotation_and_not_jwt_key(setup, monkeypatch):
    db, manager = setup
    manager.replace('1' * 64, snapshot('teacher.demo'))
    monkeypatch.setattr(settings, 'login_directory_pepper', 'new-synthetic-routing-pepper-' * 2)
    with pytest.raises(NotFoundError): manager.resolve(login_digest('teacher.demo'))
    manager.replace('1' * 64, snapshot('teacher.demo'))
    assert manager.resolve(login_digest('teacher.demo')).school_id == 1
    monkeypatch.setattr(settings, 'login_directory_pepper', settings.secret_key)
    with pytest.raises(BaseError) as error: manager.resolve(login_digest('teacher.demo'))
    assert error.value.status_code == 503


def test_no_arbitrary_school_url(setup):
    db, manager = setup
    manager.replace('1' * 64, snapshot('teacher.demo'))
    endpoint = db.query(SchoolEndpoint).filter_by(school_id=1).one()
    endpoint.legacy_hostname = 'example.net'
    db.commit()
    with pytest.raises(NotFoundError): manager.resolve(login_digest('teacher.demo'))


def test_local_snapshot_filters_deleted_disabled_and_other_school(setup):
    db, manager = setup
    db.add(SchoolBuilding(id=1, school_id=1, name='Synthetic', address='Synthetic', is_active=False))
    db.flush()
    for i, login in enumerate(['active.demo', 'inactive.demo', 'deleted.demo', 'other.demo', 'building.demo', 'chief.demo'], 1):
        db.add(User(id=i, login=login, full_name='Synthetic', hashed_password='not-a-password',
                    role=UserRole.SUPER_ADMIN if i == 6 else UserRole.TEACHER,
                    school_id=2 if i == 4 else 1, building_id=1 if i == 5 else None,
                    is_active=i != 2, deleted_at=utcnow() if i == 3 else None))
    db.commit()
    assert local_digests(db, 1) == [login_digest('active.demo')]


def test_prune_expired_without_removing_other_current_school(setup):
    db, manager = setup
    manager.replace('2' * 64, snapshot('old.demo'))
    db.query(LoginDirectoryEntry).filter_by(school_id=2).one().expires_at = utcnow() - timedelta(seconds=1)
    db.commit()
    manager.replace('1' * 64, snapshot('active.demo'))
    assert db.query(LoginDirectoryEntry).count() == 1
    assert manager.resolve(login_digest('active.demo')).school_id == 1


@pytest.mark.parametrize('mode, enabled, devices', [('local', True, True), ('legacy', True, True),
                                                 ('cloud', False, True), ('cloud', True, False)])
def test_opt_in_and_cloud_only(setup, monkeypatch, mode, enabled, devices):
    _, manager = setup
    monkeypatch.setattr(settings, 'deployment_mode', mode)
    monkeypatch.setattr(settings, 'login_directory_enabled', enabled)
    monkeypatch.setattr(settings, 'school_devices_enabled', devices)
    with pytest.raises(NotFoundError): manager.resolve(login_digest('teacher.demo'))


def test_publisher_sends_only_digests_and_checks_primary_first(setup, monkeypatch, tmp_path):
    import httpx
    from scripts import login_directory as publisher
    db, _ = setup
    db.add(User(login='synthetic.teacher', full_name='Synthetic Name Must Stay Local',
                hashed_password='synthetic-hash-must-stay-local', school_id=1,
                role=UserRole.TEACHER, is_active=True))
    db.commit()
    monkeypatch.setattr(settings, 'deployment_mode', 'local')
    monkeypatch.setenv('GBOU_SCHOOL_ID', '1')
    monkeypatch.setenv('GBOU_CLOUD_API_BASE', 'https://central.example/api/v1')
    key = tmp_path / 'synthetic.token'
    key.write_text('1' * 64)
    key.chmod(0o600)
    monkeypatch.setenv('GBOU_NODE_TOKEN_FILE', str(key))
    monkeypatch.setattr(publisher, 'SessionLocal', sessionmaker(bind=db.bind))
    requests = []
    primary = [True]

    def handle(request):
        requests.append(request)
        assert request.headers['X-School-Device-Token'] == '1' * 64
        if request.url.path.endswith('/heartbeat'):
            return httpx.Response(200, json={'role': 'primary', 'state': 'active',
                                            'is_primary': primary[0], 'generation': 1})
        import json
        assert request.method == 'PUT'
        assert json.loads(request.content) == {'generation': 1, 'login_digests': [login_digest('synthetic.teacher')]}
        assert b'synthetic.teacher' not in request.content
        assert b'Synthetic Name' not in request.content and b'synthetic-hash' not in request.content
        return httpx.Response(200, json={'published': 1})

    actual_client = httpx.Client
    monkeypatch.setattr(publisher.httpx, 'Client', lambda **options: actual_client(
        transport=httpx.MockTransport(handle), **options))
    publisher.publish()
    assert len(requests) == 2
    primary[0] = False
    with pytest.raises(ValueError): publisher.publish()
    assert len(requests) == 3  # No PUT by a replaced primary.


def test_exact_central_web_cors_is_opt_in():
    from app.config.settings import Settings
    for enabled in (False, True):
        config = Settings(database_url='sqlite:///:memory:', deployment_mode='local',
                          secret_key='synthetic-cors-key-more-than-thirty-two-characters',
                          algorithm='HS256', cors_origins='', cors_origin_regex='^$',
                          login_directory_enabled=enabled, _env_file=None)
        assert ('https://gbousecurity.ru' in config.cors_origins_list) == enabled
        assert 'https://evil.example' not in config.cors_origins_list


def test_enabled_cloud_fails_startup_without_separate_pepper():
    from app.config.settings import Settings
    from pydantic import ValidationError
    for pepper in ('', 'short', 'synthetic-jwt-key-more-than-thirty-two-characters'):
        with pytest.raises(ValidationError) as error:
            Settings(database_url='sqlite:///:memory:', deployment_mode='cloud',
                     secret_key='synthetic-jwt-key-more-than-thirty-two-characters', algorithm='HS256',
                     login_directory_enabled=True, login_directory_pepper=pepper, _env_file=None)
        assert 'synthetic-jwt-key-more-than-thirty-two-characters' not in str(error.value)


def test_snapshot_schema_rejects_raw_fields_and_oversize():
    from pydantic import ValidationError
    for payload in [dict(generation=1, login_digests=['teacher.demo']),
                    dict(generation=1, login_digests=[], password='do-not-accept'),
                    dict(generation=1, login_digests=['a' * 64] * 10001),
                    dict(generation=0, login_digests=[])]:
        with pytest.raises(ValidationError): DirectorySnapshot.model_validate(payload)


def test_lookup_quota_is_not_a_school_login_blocker():
    from app.api.v1.login_directory import DirectoryRateLimit
    now = [0.0]
    limiter = DirectoryRateLimit(clock=lambda: now[0], attempts=2, capacity=2)
    limiter.check('synthetic-client')
    limiter.check('synthetic-client')
    with pytest.raises(BaseError) as error: limiter.check('synthetic-client')
    assert error.value.status_code == 429
    limiter.check('different-client')
    limiter.check('third-client')
    assert len(limiter.buckets) == 2
    now[0] = 61
    limiter.check('synthetic-client')


def test_route_body_limits_and_error_cache_control(setup):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.v1.login_directory import router, service
    from app.main import directory_request_limits, base_error_handler, validation_error_handler
    from fastapi.exceptions import RequestValidationError
    db, manager = setup
    app = FastAPI()
    app.include_router(router, prefix='/api/v1/login-directory')
    app.dependency_overrides[service] = lambda: manager
    app.exception_handler(BaseError)(base_error_handler)
    app.exception_handler(RequestValidationError)(validation_error_handler)
    app.middleware('http')(directory_request_limits)
    with TestClient(app) as client:
        result = client.post('/api/v1/login-directory/resolve', json={'login_digest': 'a' * 64})
        assert result.status_code == 404 and result.headers['cache-control'] == 'no-store'
        assert client.post('/api/v1/login-directory/resolve', json={'login': 'raw.demo'}).status_code == 422
        assert client.post('/api/v1/login-directory/resolve', content=b'x' * 2049).status_code == 413
        assert client.put('/api/v1/login-directory/snapshot', content=b'x' * 1048577).status_code == 413
        assert client.put('/api/v1/login-directory/snapshot', json={'generation': 1, 'login_digests': []}).status_code == 401
        result = client.put('/api/v1/login-directory/snapshot', headers={'X-School-Device-Token': '1' * 64},
                            json={'generation': 1, 'login_digests': [login_digest('teacher.demo')]})
        assert result.status_code == 200
        assert client.post('/api/v1/login-directory/resolve', json={'login_digest': login_digest('teacher.demo')}).json() == {
            'school_id': 1, 'origin': 'https://1.gbousecurity.ru'}


def test_migration015_roundtrip(tmp_path, monkeypatch):
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from alembic.script import ScriptDirectory
    from sqlalchemy import inspect
    folder = Path(__file__).parents[1] / 'alembic'
    assert ScriptDirectory(str(folder)).get_heads() == ['015_login_directory']
    spec = importlib.util.spec_from_file_location('directory_migration', folder / 'versions/015_login_directory.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = create_engine('sqlite:///' + (tmp_path / 'migration.sqlite').as_posix())
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE schools(id INTEGER PRIMARY KEY)'))
        monkeypatch.setattr(module, 'op', Operations(MigrationContext.configure(connection)))
        module.upgrade()
        assert 'login_directory_entries' in inspect(connection).get_table_names()
        module.downgrade()
        assert inspect(connection).get_table_names() == ['schools']
    engine.dispose()
