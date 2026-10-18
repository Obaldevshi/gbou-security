"""Isolated SQLite topology tests; no production services or keys."""
import base64
from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import uuid
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.config.database import Base
from app.config.settings import settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnauthorizedError, ValidationError
from app.models.school import School
from app.models.school_device import DeviceInvitation, SchoolDevice
from app.models.school_node_credential import SchoolNodeCredential
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.repositories.node_config_repository import NodeConfigRepository
from app.schemas.school_device import ActivatePrimary, EnrollDevice
from app.services.school_device_service import SchoolDeviceService, digest


def key(number):
    return base64.b64encode(bytes([number]) * 32).decode()


@pytest.fixture
def setup(tmp_path, monkeypatch):
    engine = create_engine('sqlite:///' + (tmp_path / 'registry.sqlite3').as_posix())
    Base.metadata.create_all(engine)
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    monkeypatch.setattr(settings, 'school_devices_enabled', True)
    monkeypatch.setattr(settings, 'gateway_public_key', key(99))
    monkeypatch.setattr(settings, 'gateway_endpoint', 'gateway.example:51820')
    monkeypatch.setattr(settings, 'gateway_manifest_token_hash', digest('m' * 64))
    with sessionmaker(bind=engine, expire_on_commit=False)() as db:
        db.add_all([School(id=1, full_name='Школа236', short_name='ГБОУ236', address='Москва', is_active=True),
                    School(id=2, full_name='Другая236', short_name='ГБОУ236 филиал', address='Москва', is_active=True)])
        db.commit()
        yield db, SchoolDeviceService(SchoolDeviceRepository(db))
    engine.dispose()


def enroll(service, school=1, role='primary', number=1):
    invitation = service.invite(school, role)['invitation']
    payload = EnrollDevice(invitation=invitation, device_id=uuid.uuid4(), label='Новый узел',
                           public_key=key(number) if role == 'primary' else None)
    return service.enroll(payload), payload


def activate(service, device, generation=0):
    return service.activate(device.school_id, device.device_id, ActivatePrimary(
        expected_generation=generation, previous_primary_stopped=True,
        database_ready_and_backup_verified=True))


def test_stable_numeric_address_collision_and_rename(setup):
    db, service = setup
    assert service.overview(1).hostname == '236.gbousecurity.ru'
    assert service.overview(2).hostname == '236-2.gbousecurity.ru'
    db.get(School, 1).short_name = 'Другая школа999'
    db.commit()
    assert service.overview(1).hostname == '236.gbousecurity.ru'


def test_pending_primary_not_a_writer_or_sync_client(setup):
    db, service = setup
    device, payload = enroll(service)
    assert device.state == 'pending'
    assert NodeConfigRepository(db).credential_by_hash(digest(device.token)) is None
    assert not service.gateway_manifest('m' * 64).routes
    assert service.enroll(payload).token == device.token  # Lost HTTP reply can retry safely.
    payload.device_id = uuid.uuid4()
    with pytest.raises(UnauthorizedError):
        service.enroll(payload)


def test_replacement_keeps_address_and_revokes_old_tokens(setup):
    db, service = setup
    db.add(SchoolNodeCredential(school_id=1, token_hash=digest('l' * 64), is_active=True))
    db.commit()
    first, _ = enroll(service)
    activate(service, first)
    assert NodeConfigRepository(db).credential_by_hash(digest(first.token)).device_id == first.device_id
    assert NodeConfigRepository(db).credential_by_hash(digest('l' * 64)) is None
    # A legacy key accidentally re-enabled later still cannot bypass ownership.
    db.query(SchoolNodeCredential).filter_by(school_id=1).update({'is_active': True})
    db.commit()
    assert NodeConfigRepository(db).credential_by_hash(digest('l' * 64)) is None
    second, _ = enroll(service, number=2)
    result = activate(service, second, generation=1)
    assert result.hostname == '236.gbousecurity.ru' and result.generation == 2
    assert sum(d.state == 'active' and d.role == 'primary' for d in result.devices) == 1
    with pytest.raises(UnauthorizedError):
        service.device_status(first.token)
    assert NodeConfigRepository(db).credential_by_hash(digest(first.token)) is None
    assert service.gateway_manifest('m' * 64).routes[0].device_id == second.device_id


def test_terminal_no_wg_sync_or_personal_data(setup):
    db, service = setup
    primary, _ = enroll(service)
    activate(service, primary)
    terminal, _ = enroll(service, role='terminal')
    assert terminal.gateway_endpoint is None and terminal.tunnel_ip is None
    assert terminal.gateway_public_key is None
    assert NodeConfigRepository(db).credential_by_hash(digest(terminal.token)) is None
    assert 'school_admins' not in service.device_status(terminal.token)
    with pytest.raises(ConflictError):
        activate(service, terminal, 1)
    service.revoke_terminal(1, terminal.device_id)
    with pytest.raises(UnauthorizedError):
        service.device_status(terminal.token)


def test_cannot_activate_without_fencing_and_restore_or_wrong_tenant(setup):
    _, service = setup
    device, _ = enroll(service)
    for stopped, restored in [(False, True), (True, False)]:
        with pytest.raises(ConflictError):
            service.activate(1, device.device_id, ActivatePrimary(expected_generation=0,
                             previous_primary_stopped=stopped, database_ready_and_backup_verified=restored))
    with pytest.raises(NotFoundError):
        service.activate(2, device.device_id, ActivatePrimary(expected_generation=0,
                         previous_primary_stopped=True, database_ready_and_backup_verified=True))
    with pytest.raises(ConflictError):
        activate(service, device, 99)


def test_invite_expiry_supersession_and_role(setup):
    db, service = setup
    old = service.invite(1, 'primary')['invitation']
    current = service.invite(1, 'primary')['invitation']
    payload = EnrollDevice(invitation=old, device_id=uuid.uuid4(), label='Тест', public_key=key(1))
    with pytest.raises(UnauthorizedError):
        service.enroll(payload)
    payload.invitation = current
    invite = db.query(DeviceInvitation).filter_by(token_hash=digest(current)).one()
    invite.expires_at = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(seconds=1)
    db.commit()
    with pytest.raises(UnauthorizedError):
        service.enroll(payload)
    fresh = service.invite(1, 'primary')['invitation']
    payload.invitation, payload.public_key = fresh, None
    with pytest.raises(ValidationError):
        service.enroll(payload)


def test_duplicate_device_key_is_atomic(setup):
    db, service = setup
    first, _ = enroll(service, number=1)
    invite = service.invite(2, 'primary')['invitation']
    with pytest.raises(ConflictError):
        service.enroll(EnrollDevice(invitation=invite, device_id=uuid.uuid4(), label='Копия', public_key=key(1)))
    db.rollback()
    assert db.query(SchoolDevice).count() == 1
    assert db.query(DeviceInvitation).filter_by(token_hash=digest(invite)).one().consumed_at is None


def test_feature_default_gate_and_school_disabled(setup, monkeypatch):
    db, service = setup
    monkeypatch.setattr(settings, 'school_devices_enabled', False)
    with pytest.raises(NotFoundError):
        service.overview(1)
    monkeypatch.setattr(settings, 'school_devices_enabled', True)
    db.get(School, 1).is_active = False
    db.commit()
    with pytest.raises(ForbiddenError):
        service.invite(1, 'primary')


def test_manifest_requires_separate_key_and_never_contains_tokens(setup):
    _, service = setup
    device, _ = enroll(service)
    activate(service, device)
    with pytest.raises(UnauthorizedError):
        service.gateway_manifest(device.token)
    result = service.gateway_manifest('m' * 64).model_dump_json()
    assert device.token not in result and 'hashed_password' not in result and 'school_admin' not in result
    assert device.token not in service.overview(1).model_dump_json()


@pytest.fixture
def renderer():
    source = Path(__file__).parents[1] / 'local-node/gateway/managed_routes.py'
    spec = importlib.util.spec_from_file_location('managed_routes_test', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_gateway_validation_and_preserve_unmanaged(renderer):
    row = dict(hostname='236.gbousecurity.ru', tunnel_ip='10.78.0.2', public_key=key(3), generation=1)
    routes = renderer.validate_routes({'schema_version': 1, 'routes': [row]},
              [dict(hostname='school-2036.gbousecurity.ru', tunnel_ip='10.77.203.2')])
    output = renderer.render_haproxy(routes)
    assert '10.78.0.2:443' in output and '10.77.203.2:443' in output
    assert 'ssl crt' not in output and '8765' not in output
    current = '[Interface]\nPrivateKey = TEST-ONLY\n\n[Peer]\nPublicKey = ' + key(4) + '\nAllowedIPs = 10.77.203.2/32\n'
    wg = renderer.render_wireguard(current, set(), routes)
    assert key(4) in wg and key(3) in wg and 'TEST-ONLY' in wg
    replaced = renderer.render_wireguard(wg, {key(3)}, [])
    assert key(3) not in replaced and key(4) in replaced
    for field, value in [('hostname', 'evil.example'), ('tunnel_ip', '127.0.0.1'), ('tunnel_ip', '10.77.203.1')]:
        with pytest.raises(ValueError):
            renderer.validate_routes({'schema_version': 1, 'routes': [row | {field: value}]})
    with pytest.raises(ValueError):
        renderer.validate_routes({'schema_version': 1, 'routes': [row, row]})


def test_invitation_compare_and_set_prevents_double_consume(setup):
    db, service = setup
    raw = service.invite(1, 'primary')['invitation']
    invite = db.query(DeviceInvitation).filter_by(token_hash=digest(raw)).one()
    repository = SchoolDeviceRepository(db)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    assert repository.consume(invite, str(uuid.uuid4()), now)
    assert not repository.consume(invite, str(uuid.uuid4()), now)
    db.rollback()


def test_route_requires_chief_and_no_store(setup):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from fastapi.responses import JSONResponse
    from types import SimpleNamespace
    from app.api.v1.school_devices import system_router, device_router, service as dependency
    from app.core.dependencies import get_current_user
    from app.models.user import UserRole
    from app.core.exceptions import BaseError
    _, manager = setup
    app = FastAPI()
    app.include_router(system_router, prefix='/system')
    app.include_router(device_router, prefix='/devices')
    app.dependency_overrides[dependency] = lambda: manager
    @app.exception_handler(BaseError)
    async def exception(_, error):
        return JSONResponse({'code': error.code}, status_code=error.status_code)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(role=UserRole.SCHOOL_ADMIN, must_change_password=False)
    with TestClient(app) as client:
        assert client.get('/system/schools/1/devices').status_code == 403
        app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(role=UserRole.SUPER_ADMIN, must_change_password=False)
        response = client.post('/system/schools/1/device-invitations', json={'role': 'primary'})
        assert response.status_code == 200 and response.headers['cache-control'] == 'no-store'
        raw = response.json()['data']['invitation']
        response = client.get('/system/schools/1/devices')
        assert raw not in response.text and response.status_code == 200
        assert client.get('/devices/gateway-manifest').status_code == 401
        assert client.post('/devices/enroll', json={}).status_code == 422


def test_new_school_gets_endpoint_automatically(setup):
    db, _ = setup
    from app.repositories.school_repository import SchoolRepository
    from app.schemas.school import SchoolCreate
    from app.services.school_service import SchoolService
    created = SchoolService(SchoolRepository(db)).create_school(SchoolCreate(
        full_name='ГБОУ Школа2367', short_name='ГБОУ2367', address='Москва'))
    assert SchoolDeviceRepository(db).endpoint(created.id).slug == '2367'


def test_migration011_roundtrip_preserves_school_records(tmp_path, monkeypatch):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from sqlalchemy import inspect, text
    source = Path(__file__).parents[1] / 'alembic/versions/011_school_devices.py'
    spec = importlib.util.spec_from_file_location('migration011_test', source)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = create_engine('sqlite:///' + (tmp_path / 'migration.sqlite3').as_posix())
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE schools (id INTEGER PRIMARY KEY, short_name TEXT)'))
        connection.execute(text("INSERT INTO schools VALUES(1, 'school236')"))
        monkeypatch.setattr(migration, 'op', Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        assert {'school_endpoints', 'school_devices', 'device_invitations'} <= set(inspect(connection).get_table_names())
        migration.downgrade()
        assert inspect(connection).get_table_names() == ['schools']
        assert connection.execute(text('SELECT short_name FROM schools')).scalar_one() == 'school236'
    engine.dispose()


def test_reconciler_installs_kernel_route_without_replacing_foreign_network(monkeypatch):
    import sys
    folder = Path(__file__).parents[1] / 'local-node/gateway'
    monkeypatch.syspath_prepend(str(folder))
    spec = importlib.util.spec_from_file_location('gateway_reconcile_test', folder / 'reconcile.py')
    worker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(worker)
    calls = []
    monkeypatch.setattr(worker.subprocess, 'check_output', lambda *a, **kw: '[]')
    monkeypatch.setattr(worker.subprocess, 'run', lambda args, **kw: calls.append(args))
    assert worker.ensure_managed_route() is True
    assert calls == [['ip', '-4', 'route', 'add', '10.78.0.0/16', 'dev', 'gbou-wg', 'proto', 'static']]
    calls.clear()
    monkeypatch.setattr(worker.subprocess, 'check_output', lambda *a, **kw: '[{"dev":"gbou-wg"}]')
    assert worker.ensure_managed_route() is False
    assert not calls
    monkeypatch.setattr(worker.subprocess, 'check_output', lambda *a, **kw: '[{"dev":"eth0"}]')
    with pytest.raises(ValueError):
        worker.ensure_managed_route()
    assert not calls


def test_reconciler_atomic_install_stays_on_target_mount(tmp_path, monkeypatch):
    import errno
    folder = Path(__file__).parents[1] / 'local-node/gateway'
    monkeypatch.syspath_prepend(str(folder))
    spec = importlib.util.spec_from_file_location('gateway_atomic_test', folder / 'reconcile.py')
    worker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(worker)
    source = tmp_path / 'state' / 'candidate'
    target = tmp_path / 'config' / 'installed'
    source.parent.mkdir()
    target.parent.mkdir()
    source.write_bytes(b'test-config-only')
    replace = worker.os.replace
    def separate_mounts(left, right):
        if Path(left).parent != Path(right).parent:
            raise OSError(errno.EXDEV, 'different sandbox mount')
        return replace(left, right)
    monkeypatch.setattr(worker.os, 'replace', separate_mounts)
    worker.atomic_install(source, target)
    assert target.read_bytes() == source.read_bytes()
    assert list(target.parent.iterdir()) == [target]
