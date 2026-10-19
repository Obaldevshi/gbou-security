"""Independent building writers. Temporary SQLite only, no live Pi/network."""
import base64
import uuid
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.config.database import Base
from app.config.settings import settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnauthorizedError
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_device import SchoolDevice, SchoolEndpoint, BuildingEndpoint, DeviceInvitation
from app.models.school_node_credential import SchoolNodeCredential
from app.models.user import User, UserRole
from app.repositories.device_pairing_repository import DevicePairingRepository
from app.repositories.node_config_repository import NodeConfigRepository
from app.schemas.device_pairing import PairingStart, PairingApproval
from app.schemas.school_device import ActivatePrimary, EnrollDevice
from app.services.device_pairing_service import DevicePairingService
from app.services.school_device_service import digest
from app.services.node_config_service import NodeConfigService


def key(n):
    return base64.b64encode(bytes([n]) * 32).decode()


@pytest.fixture
def campus(tmp_path, monkeypatch):
    engine = create_engine('sqlite:///' + (tmp_path / 'test.sqlite3').as_posix())
    Base.metadata.create_all(engine)
    for k, v in dict(deployment_mode='cloud', school_devices_enabled=True,
                     building_nodes_enabled=True, device_pairing_enabled=True,
                     gateway_public_key=key(99), gateway_endpoint='example.test:51820',
                     gateway_manifest_token_hash=digest('m' * 64)).items():
        monkeypatch.setattr(settings, k, v)
    with sessionmaker(bind=engine, expire_on_commit=False)() as db:
        db.add_all([School(id=i, full_name=f'School{i}', short_name=f'GBOU {236+i}', address='Test', is_active=True) for i in (1, 2)])
        db.flush()
        db.add_all([SchoolBuilding(id=i, school_id=1 if i < 3 else 2,
            name=f'Building{i}', address='Test', is_active=True) for i in (1, 2, 3)])
        for i, building, role in [(10, None, UserRole.SCHOOL_ADMIN), (11, 1, UserRole.SCHOOL_ADMIN),
                                  (12, 2, UserRole.SCHOOL_ADMIN), (13, 1, UserRole.TEACHER)]:
            db.add(User(id=i, school_id=1, building_id=building, login=f'admin{i}', full_name='Test',
                hashed_password='NOT-A-REAL-PASSWORD', role=role, is_active=True, must_change_password=False))
        db.commit()
        yield db, DevicePairingService(DevicePairingRepository(db)), db.get(User, 10)
    engine.dispose()


def pair(service, actor, building, n, role='primary', *, version=2):
    start = PairingStart(device_id=uuid.uuid4(), label='Test Pi', public_key=key(n), poll_token='p' * 64)
    created = service.start(start)
    service.approve(actor, created['request_id'], PairingApproval(school_id=1, building_id=building,
        role=role, code=created['verification_code'], scope_version=version))
    return service.poll(created['request_id'], start.poll_token)['enrollment']


def activate(service, device, generation=0):
    return service.activate(1, device['device_id'], ActivatePrimary(expected_generation=generation,
        previous_primary_stopped=True, database_ready_and_backup_verified=True))


def test_two_building_writers_and_independent_replacement(campus):
    db, service, actor = campus
    first, second = pair(service, actor, 1, 1), pair(service, actor, 2, 2)
    activate(service, first)
    activate(service, second)
    assert first['hostname'] == '237-1.gbousecurity.ru'
    assert second['hostname'] == '237-2.gbousecurity.ru'
    assert {r.building_id for r in service.gateway_manifest('m' * 64).routes} == {1, 2}
    repo = NodeConfigRepository(db)
    assert repo.credential_by_hash(digest(first['token']))
    assert repo.credential_by_hash(digest(second['token']))
    replacement = pair(service, actor, 1, 3)
    result = activate(service, replacement, 1)
    assert result.generation == 2 and result.hostname == first['hostname']
    assert all(d.building_id == 1 for d in result.devices)
    assert service.device_status(second['token'])['generation'] == 1
    assert repo.credential_by_hash(digest(second['token']))
    with pytest.raises(UnauthorizedError):
        service.device_status(first['token'])
    assert db.query(SchoolDevice).filter_by(role='primary', state='active').count() == 2


def test_terminal_cannot_borrow_other_building_primary(campus):
    db, service, actor = campus
    first = pair(service, actor, 1, 1)
    activate(service, first)
    with pytest.raises(ConflictError, match='этого корпуса'):
        pair(service, actor, 2, 2, 'terminal')
    terminal = pair(service, actor, 1, 3, 'terminal')
    assert terminal['hostname'] == first['hostname']
    assert terminal['tunnel_ip'] is None and terminal['gateway_public_key'] is None
    assert NodeConfigRepository(db).credential_by_hash(digest(terminal['token'])) is None


def test_snapshot_only_own_building_and_permitted_admins(campus):
    db, service, actor = campus
    first = pair(service, actor, 1, 1)
    activate(service, first)
    snapshot = NodeConfigService(NodeConfigRepository(db)).snapshot(first['token'])
    assert snapshot.building_id == 1
    assert [b.id for b in snapshot.buildings] == [1]
    assert {u.id for u in snapshot.school_admins} == {10, 11}
    assert all('teacher' not in u.model_dump_json() for u in snapshot.school_admins)
    db.add(SchoolNodeCredential(school_id=1, token_hash=digest('l' * 64), is_active=True))
    db.commit()
    assert NodeConfigRepository(db).credential_by_hash(digest('l' * 64)) is None


def test_disabled_building_keeps_scoped_disable_sync_but_loses_public_route(campus):
    db, service, actor = campus
    first = pair(service, actor, 1, 1)
    activate(service, first)
    db.get(SchoolBuilding, 1).is_active = False
    db.commit()
    snapshot = NodeConfigService(NodeConfigRepository(db)).snapshot(first['token'])
    assert len(snapshot.buildings) == 1 and snapshot.buildings[0].id == 1
    assert snapshot.buildings[0].is_active is False
    assert not service.gateway_manifest('m' * 64).routes


def test_old_client_and_school_only_overview_fail_closed(campus):
    _, service, actor = campus
    with pytest.raises(ConflictError) as error:
        pair(service, actor, 1, 1, version=1)
    assert error.value.code == 'building_client_required'
    with pytest.raises(NotFoundError):
        service.overview(1)
    context = service.school_context(actor, 1)
    assert context['networking_scope'] == 'building'
    assert {o['building_id'] for o in context['building_overviews']} == {1, 2}


def test_foreign_or_disabled_building_never_allocates(campus):
    db, service, actor = campus
    with pytest.raises(NotFoundError):
        service.overview(1, 3)
    db.get(SchoolBuilding, 2).is_active = False
    db.commit()
    with pytest.raises(NotFoundError):
        pair(service, actor, 2, 1)
    assert db.query(BuildingEndpoint).count() == 0


def test_invitations_scoped_supersession_and_no_unscoped_invite(campus):
    db, service, _ = campus
    with pytest.raises(NotFoundError):
        service.invite(1, 'primary')
    a = service.invite(1, 'primary', 1)['invitation']
    b = service.invite(1, 'primary', 2)['invitation']
    service.invite(1, 'primary', 1)
    assert db.query(DeviceInvitation).filter_by(token_hash=digest(a)).one().revoked
    assert not db.query(DeviceInvitation).filter_by(token_hash=digest(b)).one().revoked
    device = service.enroll(EnrollDevice(invitation=b, device_id=uuid.uuid4(), label='Test', public_key=key(2)))
    assert device.building_id == 2


def test_active_building_rename_preserves_reserved_address(campus):
    db, service, actor = campus
    first = pair(service, actor, 1, 1)
    db.get(School, 1).short_name = 'School 999'
    db.get(SchoolBuilding, 1).name = 'Changed'
    db.commit()
    assert service.overview(1, 1).hostname == first['hostname']


def test_unmigrated_current_writer_is_not_silently_reassigned(campus):
    db, service, _ = campus
    db.add(SchoolEndpoint(school_id=1, slug='237', generation=3, primary_device_id='existing'))
    db.add(SchoolDevice(school_id=1, building_id=1, device_id='existing', label='Existing',
        role='primary', state='active', token_hash=digest('x' * 64), generation=3))
    db.commit()
    with pytest.raises(ConflictError) as error:
        service.overview(1, 1)
    assert error.value.code == 'building_adoption_required'
    assert db.query(BuildingEndpoint).count() == 0
    with pytest.raises(ConflictError):
        service.repo.validate_building_transition()


def test_directory_replacement_and_choices_are_building_scoped(campus, monkeypatch):
    from app.repositories.login_directory_repository import LoginDirectoryRepository
    from app.services.login_directory_service import LoginDirectoryService
    from app.schemas.login_directory import DirectorySnapshot
    from scripts.login_directory import login_digest
    db, service, actor = campus
    monkeypatch.setattr(settings, 'login_directory_enabled', True)
    monkeypatch.setattr(settings, 'login_directory_pepper', 'synthetic-separate-pepper-' * 2)
    first, second = pair(service, actor, 1, 1), pair(service, actor, 2, 2)
    activate(service, first)
    activate(service, second)
    directory = LoginDirectoryService(LoginDirectoryRepository(db), service)
    def snapshot(*names):
        return DirectorySnapshot(generation=1, login_digests=[login_digest(n) for n in names])
    directory.replace(first['token'], snapshot('teacher1', 'admin'))
    directory.replace(second['token'], snapshot('teacher2', 'admin'))
    assert directory.resolve(login_digest('teacher1')).building_id == 1
    assert directory.resolve(login_digest('teacher2')).building_id == 2
    assert {c.building_id for c in directory.choices(login_digest('admin'))} == {1, 2}
    with pytest.raises(NotFoundError) as error:
        directory.resolve(login_digest('admin'))
    assert error.value.code == 'building_selection_required'
    directory.replace(first['token'], snapshot())
    assert directory.resolve(login_digest('admin')).building_id == 2
    assert directory.resolve(login_digest('teacher2')).origin == 'https://' + second['hostname']


@pytest.mark.parametrize('scope,remote,buildings', [(None, 1, [1]), (1, None, [1]), (1, 2, [2]), (1, 1, [1, 2])])
def test_sync_scope_change_refused_before_local_write(scope, remote, buildings):
    from types import SimpleNamespace
    from scripts.node_config import validate_building_snapshot
    snapshot = SimpleNamespace(building_id=remote, buildings=[SimpleNamespace(id=b) for b in buildings])
    with pytest.raises(ValueError):
        validate_building_snapshot(snapshot, scope)
