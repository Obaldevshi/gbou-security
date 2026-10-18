"""Isolated onboarding tests. No live network, credentials or school data."""
import base64
from datetime import timedelta
import importlib.util
import json
from pathlib import Path
import uuid
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker
from pydantic import ValidationError as SchemaError
from app.config.database import Base, get_db
from app.config.settings import settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnauthorizedError
from app.core.security import create_access_token, get_password_hash, verify_token
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_device import SchoolDevice
from app.models.user import User, UserRole
from app.repositories.device_pairing_repository import DevicePairingRepository
from app.repositories.user_repository import UserRepository
from app.schemas.device_pairing import PairingStart, PairingApproval, PairingLogin, PairingPassword
from app.schemas.school_device import ActivatePrimary
from app.services.device_admin_service import DeviceAdminService
from app.services.device_pairing_service import DevicePairingService
from app.services.school_device_service import utcnow


def key(number):
    return base64.b64encode(bytes([number]) * 32).decode()


@pytest.fixture
def pairing(tmp_path, monkeypatch):
    engine = create_engine('sqlite:///' + (tmp_path / 'test.sqlite3').as_posix(), connect_args={'check_same_thread': False})
    Base.metadata.create_all(engine)
    for name, value in {'deployment_mode': 'cloud', 'school_devices_enabled': True,
                        'device_pairing_enabled': True, 'gateway_public_key': key(99),
                        'gateway_endpoint': 'gateway.example:51820'}.items():
        monkeypatch.setattr(settings, name, value)
    with sessionmaker(bind=engine, expire_on_commit=False)() as db:
        db.add_all([School(id=i, full_name=f'School {i}', short_name=f'GBOU {i}', address='Test', is_active=True) for i in (1, 2)])
        db.flush()
        db.add_all([SchoolBuilding(id=i, school_id=i, name='Building', address='Test', is_active=True) for i in (1, 2)])
        db.add_all([User(id=10, school_id=1, login='qr-admin', full_name='Test admin',
                        hashed_password=get_password_hash('Test-only-pass'), role=UserRole.SCHOOL_ADMIN,
                        is_active=True, must_change_password=False),
                    User(id=11, school_id=2, login='other', full_name='Other admin',
                        hashed_password='not-used', role=UserRole.SCHOOL_ADMIN, is_active=True, must_change_password=False)])
        db.commit()
        yield db, DevicePairingService(DevicePairingRepository(db)), db.get(User, 10)
    engine.dispose()


def start(service, number=1):
    payload = PairingStart(device_id=uuid.uuid4(), label='Raspberry test', public_key=key(number), poll_token='p' * 64)
    return service.start(payload), payload


def approve(service, actor, created, **overrides):
    fields = dict(school_id=1, building_id=1, role='primary', code=created['verification_code'])
    fields.update(overrides)
    return service.approve(actor, created['request_id'], PairingApproval(**fields))


def test_qr_primary_retry_ack_and_secret_separation(pairing):
    db, service, actor = pairing
    created, payload = start(service)
    assert service.start(payload) == created
    preview = service.preview(created['request_id'])
    assert 'verification_code' not in preview and 'poll_token' not in preview
    assert payload.poll_token not in created['qr_url']
    with pytest.raises(UnauthorizedError):
        service.poll(created['request_id'], 'x' * 64)
    assert service.poll(created['request_id'], payload.poll_token) == {'state': 'waiting'}
    overview = approve(service, actor, created)
    assert overview['overview']['devices'][0]['building_id'] == 1
    raw = json.dumps(overview)
    assert 'token' not in raw and payload.poll_token not in raw and payload.public_key not in raw
    first = service.poll(created['request_id'], payload.poll_token)
    assert first['enrollment']['state'] == 'pending'
    assert service.poll(created['request_id'], payload.poll_token) == first
    assert db.query(SchoolDevice).one().state == 'pending'
    with pytest.raises(ConflictError):
        approve(service, actor, created)
    assert service.poll(created['request_id'], payload.poll_token, complete=True) == {'state': 'completed'}
    assert service.poll(created['request_id'], payload.poll_token) == {'state': 'completed'}


def test_tenant_building_code_and_expiry(pairing):
    db, service, actor = pairing
    created, payload = start(service)
    with pytest.raises(NotFoundError):
        approve(service, actor, created, school_id=2, building_id=2)
    with pytest.raises(NotFoundError):
        approve(service, actor, created, building_id=2)
    bad = '000000' if created['verification_code'] != '000000' else '111111'
    for _ in range(5):
        with pytest.raises(UnauthorizedError):
            approve(service, actor, created, code=bad)
    with pytest.raises(NotFoundError):
        service.preview(created['request_id'])
    renewed = service.start(payload)
    assert renewed['request_id'] != created['request_id']
    row = service.repo.pairing(renewed['request_id'])
    row.expires_at = utcnow() - timedelta(days=2)
    db.commit()
    # Pruning must not delete an expired identity row we are about to reuse.
    assert service.start(payload)['request_id'] != renewed['request_id']


def test_terminal_requires_primary_and_never_gets_wg(pairing):
    db, service, actor = pairing
    primary, _ = start(service)
    child, payload = start(service, 2)
    with pytest.raises(ConflictError):
        approve(service, actor, child, role='terminal')
    approve(service, actor, primary)
    primary_id = db.query(SchoolDevice).one().device_id
    service.activate(1, primary_id, ActivatePrimary(expected_generation=0,
        previous_primary_stopped=True, database_ready_and_backup_verified=True))
    approve(service, actor, child, role='terminal')
    data = service.poll(child['request_id'], payload.poll_token)['enrollment']
    assert data['state'] == 'active' and data['building_id'] == 1
    for name in ('gateway_public_key', 'gateway_endpoint', 'tunnel_ip'):
        assert data[name] is None
    assert 'school_admins' not in data


def test_scoped_auth_expiry_roles_password_change(pairing):
    db, _, actor = pairing
    auth = DeviceAdminService(UserRepository(db))
    login = PairingLogin(login=actor.login, password='Test-only-pass')
    session = auth.login(login)
    token = session['access_token']
    assert verify_token(token) is None  # Must not authorize ordinary school APIs.
    assert auth.authenticate(token).id == actor.id
    from jose import jwt
    claims = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm], audience='device-onboarding')
    claims['exp'] = 1
    with pytest.raises(UnauthorizedError):
        auth.authenticate(jwt.encode(claims, settings.secret_key, algorithm=settings.algorithm))
    with pytest.raises(UnauthorizedError):
        auth.authenticate(create_access_token(actor.id))
    actor.must_change_password = True
    db.commit()
    limited = auth.login(login)
    assert limited['password_change_required']
    with pytest.raises(ForbiddenError):
        auth.authenticate(limited['access_token'])
    changed = auth.change_password(limited['access_token'], PairingPassword(new_password='Changed-test-pass'))
    assert not changed['password_change_required']
    with pytest.raises(UnauthorizedError):
        auth.authenticate(token)
    with pytest.raises(UnauthorizedError):
        auth.authenticate(limited['access_token'])
    actor.role = UserRole.TEACHER
    db.commit()
    with pytest.raises(UnauthorizedError):
        auth.login(PairingLogin(login=actor.login, password='Changed-test-pass'))


def test_http_headers_validation_and_qr_payload(pairing):
    db, service, actor = pairing
    from app.api.v1.device_pairing import admin, public
    app = FastAPI()
    app.include_router(public, prefix='/api/v1/devices/pairings')
    app.include_router(admin, prefix='/api/v1/device-admin')
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as client:
        response = client.post('/api/v1/device-admin/login', json={'login': actor.login, 'password': 'Test-only-pass'})
        assert response.status_code == 200
        assert response.headers['cache-control'] == 'no-store'
        bearer = {'Authorization': 'Bearer ' + response.json()['access_token']}
        schools = client.get('/api/v1/device-admin/context', headers=bearer).json()['schools']
        assert [s['id'] for s in schools] == [1]
        assert client.get('/api/v1/device-admin/schools/2', headers=bearer).status_code == 404
        assert client.get('/api/v1/device-admin/context').status_code == 401
        assert client.post('/api/v1/devices/pairings', json={}).status_code == 422
        created, payload = start(service)
        path = '/api/v1/devices/pairings/' + created['request_id']
        svg = client.get(path + '/qr.svg')
        assert svg.status_code == 200 and '<svg' in svg.text
        assert payload.poll_token not in svg.text and created['verification_code'] not in svg.text
        assert client.post(path + '/poll').status_code == 401
        assert client.post('/api/v1/device-admin/pairings/not-a-uuid/inspect', headers=bearer).status_code == 422


def test_input_validation():
    with pytest.raises(SchemaError):
        PairingStart(device_id=uuid.uuid4(), label='Test', public_key='invalid', poll_token='p' * 64)
    with pytest.raises(SchemaError):
        PairingApproval(school_id=1, building_id=1, role='primary', code='１２３４５６')


def test_feature_off_and_bad_gateway(pairing, monkeypatch):
    _, service, actor = pairing
    created, _ = start(service)
    monkeypatch.setattr(settings, 'gateway_public_key', 'bad key')
    with pytest.raises(ConflictError):
        approve(service, actor, created)
    monkeypatch.setattr(settings, 'device_pairing_enabled', False)
    with pytest.raises(NotFoundError):
        service.context(actor)


def test_migration012_roundtrip(tmp_path, monkeypatch):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    source = Path(__file__).parents[1] / 'alembic/versions/012_device_pairing.py'
    spec = importlib.util.spec_from_file_location('qr_migration_test', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = create_engine('sqlite:///' + (tmp_path / 'migration.sqlite').as_posix())
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE school_buildings (id INTEGER PRIMARY KEY)'))
        connection.execute(text('CREATE TABLE school_devices (id INTEGER PRIMARY KEY, label TEXT)'))
        connection.execute(text("INSERT INTO school_devices VALUES (1, 'existing')"))
        monkeypatch.setattr(module, 'op', Operations(MigrationContext.configure(connection)))
        module.upgrade()
        assert 'device_pairings' in inspect(connection).get_table_names()
        assert 'building_id' in {c['name'] for c in inspect(connection).get_columns('school_devices')}
        module.downgrade()
        assert connection.execute(text('SELECT label FROM school_devices')).scalar_one() == 'existing'
        assert 'building_id' not in {c['name'] for c in inspect(connection).get_columns('school_devices')}
    engine.dispose()
