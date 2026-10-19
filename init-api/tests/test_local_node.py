"""Real SQLite/encryption checks. Never connect to the project's live database."""
import json
import sqlite3
from pathlib import Path

import pytest
from cryptography.exceptions import InvalidTag
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import sessionmaker

from app.config.database import Base
from app.config.settings import settings
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.user import User, UserRole
from scripts import local_node, node_config

SECRET = "test-only-archive-secret-123456789"


@pytest.fixture
def local_db(tmp_path, monkeypatch):
    path = tmp_path / "school.sqlite3"
    url = f"sqlite:///{path.as_posix()}"
    engine = create_engine(url)

    @event.listens_for(engine, "connect")
    def foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    monkeypatch.setattr(settings, "database_url", url)
    monkeypatch.setattr(settings, "deployment_mode", "local")
    monkeypatch.setattr(local_node, "engine", engine)
    factory = sessionmaker(bind=engine, autoflush=False)
    monkeypatch.setattr(node_config, "SessionLocal", factory)
    monkeypatch.setattr(local_node, "_passphrase", lambda **_: SECRET)
    local_node.init_local()
    yield path, engine, factory
    engine.dispose()


def seed_school(factory):
    with factory.begin() as db:
        db.add(School(id=1, full_name="Школа", short_name="2036", address="Москва"))
        db.flush()
        db.add(SchoolBuilding(id=1, school_id=1, name="Корпус 1", address="Москва"))
        db.flush()
        db.add(User(id=5, school_id=1, login="admin", full_name="Администратор",
                    hashed_password="central-old", role=UserRole.SCHOOL_ADMIN,
                    must_change_password=False))
        db.add(User(id=10, school_id=1, building_id=1, login="teacher", full_name="Учитель",
                    hashed_password="teacher-secret", role=UserRole.TEACHER))


def snapshot(admin_id=5, password="central-old"):
    return {"message": "ok", "data": {
        "school": {"id": 1, "full_name": "Школа", "short_name": "2036", "address": "Москва", "is_active": True},
        "buildings": [{"id": 1, "school_id": 1, "name": "Корпус 1", "address": "Москва", "is_active": True}],
        "school_admins": [{"id": admin_id, "school_id": 1, "login": "admin" if admin_id == 5 else "newadmin",
                           "full_name": "Администратор", "phone": None, "hashed_password": password,
                           "is_active": True, "must_change_password": False}],
    }}


def test_deleted_central_admin_is_scrubbed_and_stale_sync_does_not_restore(local_db, monkeypatch, tmp_path):
    _,_,factory=local_db
    seed_school(factory)
    document=snapshot()
    document['data']['school_admins'][0].update(login='deleted-synthetic', full_name='Удалённый сотрудник',
        phone=None, is_active=False, hashed_password='synthetic-irreversible-hash', deleted_at='2026-10-18T00:00:00Z')
    setup_sync(monkeypatch,tmp_path,document)
    node_config.sync()
    with factory() as db:
        user=db.get(User,5)
        assert user.deleted_at is not None and not user.is_active and user.login=='deleted-synthetic'
    # Same transport fixture, restored/stale central snapshot must not restore identity.
    document['data']['school_admins'][0].update(login='admin',full_name='Old Identity',is_active=True,deleted_at=None)
    node_config.sync()
    with factory() as db:
        user=db.get(User,5)
        assert user.login=='deleted-synthetic' and user.full_name=='Удалённый сотрудник' and not user.is_active


def setup_sync(monkeypatch, tmp_path, document):
    token = tmp_path / "token"
    token.write_text("t" * 64)
    token.chmod(0o600)
    monkeypatch.setenv("GBOU_CLOUD_API_BASE", "https://cloud.example/api/v1")
    monkeypatch.setenv("GBOU_SCHOOL_ID", "1")
    monkeypatch.setenv("GBOU_NODE_TOKEN_FILE", str(token))

    class Response:
        def raise_for_status(self):
            pass

        def json(self):
            return document

    def get(url, **kwargs):
        assert url == "https://cloud.example/api/v1/node/config"
        assert kwargs["follow_redirects"] is False
        assert kwargs["headers"]["X-School-Node-Token"] == "t" * 64
        return Response()

    monkeypatch.setattr(node_config.httpx, "get", get)


def test_transfer_is_school_scoped_and_import_is_not_repeatable(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    seed_school(factory)
    with factory.begin() as db:
        db.add(School(id=2, full_name="Другая школа", short_name="2", address="Москва"))
        db.flush()
        db.add(User(id=20, school_id=2, login="other", full_name="Другой учитель",
                    hashed_password="secret", role=UserRole.TEACHER))
    archive = tmp_path / "transfer.gbou"
    monkeypatch.setattr(settings, "deployment_mode", "legacy")
    local_node.export_school(1, archive)
    document = json.loads(local_node._open(archive.read_bytes(), SECRET))
    assert {u["id"] for u in document["rows"]["users"]} == {5, 10}
    assert "Другой учитель" not in archive.read_bytes().decode("utf-8", errors="ignore")
    target_path = tmp_path / "target.sqlite3"
    target = create_engine(f"sqlite:///{target_path.as_posix()}")
    monkeypatch.setattr(settings, "deployment_mode", "local")
    monkeypatch.setattr(settings, "database_url", str(target.url))
    monkeypatch.setattr(local_node, "engine", target)
    try:
        local_node.import_school(archive)
        with target.connect() as db:
            assert len(db.execute(select(Base.metadata.tables["users"])).all()) == 2
        with pytest.raises(ValueError, match="непустую"):
            local_node.import_school(archive)
    finally:
        target.dispose()


def test_archive_rejects_other_school_and_outside_links():
    rows = {name: [] for name in local_node.ORDER}
    rows["schools"] = [{"id": 1}]
    rows["users"] = [{"id": 5, "school_id": 2, "role": "teacher"}]
    document = {"schema": 1, "school_id": 1, "rows": rows}
    with pytest.raises(ValueError, match="другой школы"):
        local_node._validate_school_archive(document)
    rows["users"][0]["school_id"] = 1
    rows["users"][0]["building_id"] = 999
    with pytest.raises(ValueError, match="пределы школы"):
        local_node._validate_school_archive(document)


def test_backup_restore_tamper_and_overwrite_protection(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    seed_school(factory)
    usb = tmp_path / "usb"
    usb.mkdir()
    password_file = tmp_path / "backup.key"
    password_file.write_text(SECRET)
    password_file.chmod(0o600)
    with pytest.raises(ValueError, match="не смонтирована"):
        local_node.backup_usb(usb, password_file)
    monkeypatch.setattr(Path, "is_mount", lambda self: self == usb)
    local_node.backup_usb(usb, password_file)
    archive = next(usb.glob("*.gbou"))
    restored = tmp_path / "restored.sqlite3"
    local_node.restore_to_file(archive, restored)
    with sqlite3.connect(restored) as db:
        assert db.execute("SELECT count(*) FROM users").fetchone()[0] == 2
    original = restored.read_bytes()
    with pytest.raises(FileExistsError):
        local_node.restore_to_file(archive, restored)
    assert restored.read_bytes() == original
    damaged = bytearray(archive.read_bytes())
    damaged[-18] ^= 1
    archive.write_bytes(damaged)
    with pytest.raises(InvalidTag):
        local_node.restore_to_file(archive, tmp_path / "bad.sqlite3")
    assert not (tmp_path / "bad.sqlite3").exists()


def test_sync_preserves_local_password_until_explicit_central_reset(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    seed_school(factory)
    document = snapshot()
    setup_sync(monkeypatch, tmp_path, document)
    node_config.sync()
    with factory.begin() as db:
        db.get(User, 5).hashed_password = "local-new"
    node_config.sync()
    with factory() as db:
        assert db.get(User, 5).hashed_password == "local-new"
    document["data"]["school_admins"][0]["hashed_password"] = "central-reset"
    node_config.sync()
    with factory() as db:
        assert db.get(User, 5).hashed_password == "central-reset"
        assert db.get(User, 10).hashed_password == "teacher-secret"


def test_sync_admin_id_collision_does_not_replace_teacher(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    seed_school(factory)
    setup_sync(monkeypatch, tmp_path, snapshot(admin_id=10))
    node_config.sync()
    with factory() as db:
        assert db.get(User, 10).role == UserRole.TEACHER
        assert db.get(User, -10).role == UserRole.SCHOOL_ADMIN
        assert db.get(User, 5).is_active is False


def test_sync_wrong_school_rolls_back(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    seed_school(factory)
    document = snapshot()
    document["data"]["school"]["id"] = 2
    setup_sync(monkeypatch, tmp_path, document)
    with pytest.raises(ValueError, match="другой школы"):
        node_config.sync()
    with factory() as db:
        assert db.get(User, 5).is_active


def test_provision_existing_file_is_never_deleted(local_db, tmp_path, monkeypatch):
    seed_school(local_db[2])
    monkeypatch.setattr(settings, "deployment_mode", "cloud")
    key = tmp_path / "existing.key"
    key.write_text("KEEP")
    with pytest.raises(FileExistsError):
        node_config.provision(1, key)
    assert key.read_text() == "KEEP"


def test_new_school_enrollment_and_local_user_ids_stay_positive(local_db, tmp_path, monkeypatch):
    path, engine, factory = local_db
    setup_sync(monkeypatch, tmp_path, snapshot())
    node_config.sync(enroll_empty=True)
    with factory.begin() as db:
        assert db.get(User, -5).role == UserRole.SCHOOL_ADMIN
        teacher = User(school_id=1, building_id=1, login='newteacher', full_name='Учитель',
                       hashed_password='local', role=UserRole.TEACHER)
        db.add(teacher)
        db.flush()
        assert teacher.id > 0


def test_private_archives_never_overwrite_existing_files(tmp_path):
    output = tmp_path / 'archive.gbou'
    output.write_bytes(b'KEEP')
    with pytest.raises(FileExistsError):
        local_node._write_private(output, b'REPLACE')
    assert output.read_bytes() == b'KEEP'


def test_restore_rejects_logically_broken_foreign_keys(local_db, tmp_path):
    path, engine, factory = local_db
    seed_school(factory)
    broken = tmp_path / 'broken.sqlite3'
    import shutil
    from contextlib import closing
    shutil.copyfile(path, broken)
    with closing(sqlite3.connect(broken)) as db:
        db.execute('UPDATE users SET school_id=999 WHERE id=10')
        db.commit()
    archive = tmp_path / 'broken.gbou'
    local_node._encrypt_file(broken, archive, SECRET)
    destination = tmp_path / 'recovery.sqlite3'
    with pytest.raises(RuntimeError, match='связи'):
        local_node.restore_to_file(archive, destination)
    assert not destination.exists()
