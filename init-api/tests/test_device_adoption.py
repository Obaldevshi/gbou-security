"""Legacy adoption: isolated fixtures only, no production credentials."""
import base64
import importlib.util
from pathlib import Path
import uuid
import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker
from app.config.database import Base
from app.config.settings import settings
from app.core.exceptions import ConflictError, NotFoundError
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_device import SchoolEndpoint, SchoolDevice
from app.models.school_node_credential import SchoolNodeCredential
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.repositories.node_config_repository import NodeConfigRepository
from app.schemas.device_adoption import AdoptExistingPrimary
from app.schemas.school_device import ActivatePrimary, EnrollDevice
from app.services.school_device_service import digest
from app.services.device_adoption_service import DeviceAdoptionService


def key(number):
    return base64.b64encode(bytes([number]) * 32).decode()


@pytest.fixture
def adoption(tmp_path, monkeypatch):
    engine = create_engine('sqlite:///' + (tmp_path / 'registry.sqlite').as_posix())
    Base.metadata.create_all(engine)
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    monkeypatch.setattr(settings, 'school_devices_enabled', True)
    monkeypatch.setattr(settings, 'gateway_public_key', key(99))
    monkeypatch.setattr(settings, 'gateway_endpoint', 'gateway.example:51820')
    with sessionmaker(bind=engine, expire_on_commit=False)() as db:
        db.add(School(id=2, full_name='Test', short_name='GBOU2036', address='Test', is_active=True))
        db.flush()
        db.add(SchoolBuilding(id=1, school_id=2, name='Building', address='Test', is_active=True))
        db.add(SchoolEndpoint(school_id=2, slug='2036', generation=0))
        db.add(SchoolNodeCredential(school_id=2, token_hash=digest('test-only-token' * 4), is_active=True))
        db.commit()
        plan = AdoptExistingPrimary(school_id=2, building_id=1, device_id=uuid.uuid4(), label='Existing Pi',
            public_key=key(1), tunnel_ip='10.77.203.2', hostname='school-2036.gbousecurity.ru',
            expected_generation=0, credential_fingerprint=digest(digest('test-only-token' * 4)),
            same_writer_verified=True, backup_restore_verified=True)
        yield db, DeviceAdoptionService(SchoolDeviceRepository(db)), plan
    engine.dispose()


def test_dry_run_and_idempotent_adoption_keep_scope_and_address(adoption):
    db, service, plan = adoption
    assert service.adopt(plan)['state'] == 'validated'
    assert not db.query(SchoolDevice).count()
    assert service.adopt(plan, apply=True)['state'] == 'adopted'
    assert service.adopt(plan, apply=True)['state'] == 'already_adopted'
    assert db.query(SchoolDevice).count() == 1
    assert db.query(SchoolNodeCredential).one().is_active is False
    endpoint = db.query(SchoolEndpoint).one()
    assert endpoint.slug == '2036' and endpoint.legacy_hostname == plan.hostname
    assert service.overview(2).hostname == plan.hostname
    device = NodeConfigRepository(db).credential_by_hash(digest('test-only-token' * 4))
    assert device.device_id == str(plan.device_id)
    assert service.device_status('test-only-token' * 4)['is_primary']
    # The same adopted key is NOT a manifest key or a school-login token.
    from app.core.exceptions import UnauthorizedError
    with pytest.raises(UnauthorizedError):
        service.gateway_manifest('test-only-token' * 4)


def test_adoption_rejects_wrong_proof_generation_building_attestations(adoption):
    db, service, plan = adoption
    for changes, error in [({'credential_fingerprint': '0' * 64}, ConflictError),
                           ({'expected_generation': 1}, ConflictError),
                           ({'building_id': 99}, NotFoundError),
                           ({'same_writer_verified': False}, ConflictError),
                           ({'backup_restore_verified': False}, ConflictError)]:
        with pytest.raises(error):
            service.adopt(plan.model_copy(update=changes), apply=True)
        db.rollback()
    assert not db.query(SchoolDevice).count()
    assert db.query(SchoolNodeCredential).one().is_active


def test_replacement_revokes_old_device_but_keeps_legacy_url(adoption):
    _, service, plan = adoption
    service.adopt(plan, apply=True)
    invite = service.invite(2, 'primary')['invitation']
    new = service.enroll(EnrollDevice(invitation=invite, device_id=uuid.uuid4(), label='Replacement', public_key=key(2)))
    assert new.hostname == plan.hostname
    result = service.activate(2, new.device_id, ActivatePrimary(expected_generation=1,
        previous_primary_stopped=True, database_ready_and_backup_verified=True))
    assert result.generation == 2 and result.hostname == plan.hostname
    from app.core.exceptions import UnauthorizedError
    with pytest.raises(UnauthorizedError):
        service.device_status('test-only-token' * 4)


def test_explicit_operator_rollback_is_cas_guarded(adoption):
    db, service, plan = adoption
    service.adopt(plan, apply=True)
    with pytest.raises(ConflictError):
        service.rollback_adoption(2, plan.device_id, 99)
    db.rollback()
    assert service.rollback_adoption(2, plan.device_id, 1)['state'] == 'legacy_restored'
    assert NodeConfigRepository(db).credential_by_hash(digest('test-only-token' * 4)) is not None
    assert db.query(SchoolDevice).one().state == 'revoked'


@pytest.fixture
def renderer():
    source = Path(__file__).parents[1] / 'local-node/gateway/managed_routes.py'
    spec = importlib.util.spec_from_file_location('adopt_routes_test', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_gateway_ownership_transfer_replacement_and_fail_closed(renderer):
    pin = {'hostname': 'school-2036.gbousecurity.ru', 'school_id': 2, 'tunnel_ip': '10.77.203.2',
           'public_key': key(1), 'managed_only': True}
    row = {k: v for k, v in pin.items() if k != 'managed_only'} | {'generation': 1}
    current = '[Interface]\nPrivateKey = TEST-ONLY\n\n[Peer]\nPublicKey = ' + key(1) + '\nAllowedIPs = 10.77.203.2/32\n'
    routes = renderer.validate_routes({'schema_version': 1, 'routes': [row]}, [pin])
    assert len(routes) == 1 and routes[0]['adopted_legacy']
    wireguard = renderer.render_wireguard(current, set(), routes)
    assert wireguard.count(key(1)) == 1 and '10.77.203.2/32' in wireguard
    for changes in ({'public_key': key(2)}, {'school_id': 3}, {'tunnel_ip': '10.77.203.3'}):
        with pytest.raises(ValueError):
            renderer.validate_routes({'schema_version': 1, 'routes': [row | changes]}, [pin])
    assert renderer.validate_routes({'schema_version': 1, 'routes': []}, [pin]) == []
    new = row | {'public_key': key(2), 'tunnel_ip': '10.78.0.3', 'generation': 2}
    replaced = renderer.render_wireguard(wireguard, {key(1)}, renderer.validate_routes({'schema_version': 1, 'routes': [new]}, [pin]))
    assert key(1) not in replaced and key(2) in replaced
    # Explicit operator rollback restores the exact pinned peer, never arbitrary LAN.
    fallback = renderer.validate_routes({'schema_version': 1, 'routes': []}, [pin | {'managed_only': False}])
    restored = renderer.render_wireguard(current, {key(1)}, fallback)
    assert restored.count(key(1)) == 1
    assert key(1) in renderer.render_wireguard('[Interface]\nPrivateKey = TEST-ONLY\n', set(), fallback)


def test_gateway_state_records_adoption_even_without_network_changes(tmp_path, monkeypatch):
    folder = Path(__file__).parents[1] / 'local-node/gateway'
    monkeypatch.syspath_prepend(str(folder))
    spec = importlib.util.spec_from_file_location('adopt_reconcile_test', folder / 'reconcile.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    state = tmp_path / 'state.json'
    module.save_managed_state(state, {'keys': [], 'generations': {}}, {'routes': [{'school_id': 2, 'generation': 1, 'public_key': key(1)}]})
    import json
    assert json.loads(state.read_text()) == {'keys': [key(1)], 'generations': {'2': 1}}


def test_migration013_preserves_slug(tmp_path, monkeypatch):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    source = Path(__file__).parents[1] / 'alembic/versions/013_legacy_device_address.py'
    spec = importlib.util.spec_from_file_location('adopt_migration_test', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = create_engine('sqlite:///' + (tmp_path / 'migration.sqlite').as_posix())
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE school_endpoints(id INTEGER PRIMARY KEY,slug TEXT)'))
        connection.execute(text("INSERT INTO school_endpoints VALUES(1,'2036')"))
        monkeypatch.setattr(module, 'op', Operations(MigrationContext.configure(connection)))
        module.upgrade()
        assert 'legacy_hostname' in {c['name'] for c in inspect(connection).get_columns('school_endpoints')}
        module.downgrade()
        assert connection.execute(text('SELECT slug FROM school_endpoints')).scalar_one() == '2036'
    engine.dispose()


def test_qr_child_after_adoption_keeps_primary_url_and_cannot_sync(adoption, monkeypatch):
    """The actual next installation path, entirely isolated from production."""
    from app.models.user import User, UserRole
    from app.repositories.device_pairing_repository import DevicePairingRepository
    from app.schemas.device_pairing import PairingStart, PairingApproval
    from app.services.device_pairing_service import DevicePairingService
    from app.core.exceptions import UnauthorizedError

    db, service, plan = adoption
    monkeypatch.setattr(settings, 'device_pairing_enabled', True)
    service.adopt(plan, apply=True)
    actor = User(id=42, school_id=2, login='fixture-admin', full_name='Fixture',
                 hashed_password='unused', role=UserRole.SCHOOL_ADMIN,
                 is_active=True, must_change_password=False)
    db.add(actor)
    db.commit()
    pairing = DevicePairingService(DevicePairingRepository(db))
    child = PairingStart(device_id=uuid.uuid4(), label='Fixture terminal',
                         public_key=key(2), poll_token='p' * 64)
    created = pairing.start(child)
    pairing.approve(actor, created['request_id'], PairingApproval(
        school_id=2, building_id=1, role='terminal', code=created['verification_code']))
    data = pairing.poll(created['request_id'], child.poll_token)['enrollment']
    assert data['hostname'] == plan.hostname and data['role'] == 'terminal'
    assert data['state'] == 'active' and data['building_id'] == 1
    assert all(data[name] is None for name in ('tunnel_ip', 'gateway_endpoint', 'gateway_public_key'))
    assert NodeConfigRepository(db).credential_by_hash(digest(data['token'])) is None
    assert service.device_status(data['token'])['is_primary'] is False
    with pytest.raises(UnauthorizedError):
        service.gateway_manifest(data['token'])
    assert service.overview(2).generation == 1
    assert service.overview(2).hostname == plan.hostname
    assert len(db.query(SchoolDevice).all()) == 2
    with pytest.raises(ConflictError):
        service.rollback_adoption(2, plan.device_id, 1)
