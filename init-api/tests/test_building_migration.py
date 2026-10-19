"""Exercise the real Alembic upgrade/downgrade against isolated old schemas."""
import importlib.util
from pathlib import Path
import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, inspect, text


@pytest.fixture
def old_registry(tmp_path, monkeypatch):
    engine = create_engine('sqlite:///' + (tmp_path / 'migration.sqlite').as_posix())
    source = Path(__file__).parents[1] / 'alembic/versions/016_building_endpoints.py'
    spec = importlib.util.spec_from_file_location('building_migration_test', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with engine.begin() as db:
        statements = [
            'CREATE TABLE schools (id INTEGER PRIMARY KEY)',
            'CREATE TABLE school_buildings (id INTEGER PRIMARY KEY, school_id INTEGER)',
            'CREATE TABLE school_devices (device_id TEXT PRIMARY KEY, school_id INTEGER, building_id INTEGER, role TEXT, state TEXT, generation INTEGER)',
            'CREATE TABLE school_endpoints (id INTEGER PRIMARY KEY, school_id INTEGER, slug TEXT, legacy_hostname TEXT, generation INTEGER, primary_device_id TEXT, created_at DATETIME, updated_at DATETIME)',
            'CREATE TABLE device_invitations (id INTEGER PRIMARY KEY, school_id INTEGER)',
            'CREATE TABLE login_directory_entries (id INTEGER PRIMARY KEY, school_id INTEGER, lookup_tag TEXT, generation INTEGER, expires_at DATETIME, created_at DATETIME, updated_at DATETIME)',
            'CREATE TABLE students (id INTEGER PRIMARY KEY, marker TEXT)',
            'INSERT INTO schools VALUES (2)', 'INSERT INTO school_buildings VALUES (1,2)',
            "INSERT INTO school_devices VALUES ('current',2,1,'primary','active',3)",
            "INSERT INTO school_endpoints VALUES (1,2,'2036','school-2036.gbousecurity.ru',3,'current',NULL,NULL)",
            "INSERT INTO login_directory_entries VALUES (1,2,'synthetic-hmac-tag',3,'2099-01-01',NULL,NULL)",
            "INSERT INTO students VALUES (1,'unchanged synthetic data')",
        ]
        for statement in statements:
            db.execute(text(statement))
        monkeypatch.setattr(module, 'op', Operations(MigrationContext.configure(db)))
        yield db, module
    engine.dispose()


def test_upgrade_keeps_url_generation_and_all_school_rows(old_registry):
    db, migration = old_registry
    migration.upgrade()
    assert db.execute(text('SELECT school_id,building_id,legacy_hostname,generation,primary_device_id FROM building_endpoints')).one() == (
        2, 1, 'school-2036.gbousecurity.ru', 3, 'current')
    assert db.execute(text('SELECT lookup_tag,generation FROM building_login_directory_entries')).one() == ('synthetic-hmac-tag', 3)
    assert db.execute(text('SELECT marker FROM students')).scalar_one() == 'unchanged synthetic data'
    migration.downgrade()
    assert 'building_endpoints' not in inspect(db).get_table_names()
    assert db.execute(text('SELECT primary_device_id,generation FROM school_endpoints')).one() == ('current', 3)
    assert db.execute(text('SELECT marker FROM students')).scalar_one() == 'unchanged synthetic data'


@pytest.mark.parametrize('change', [
    "UPDATE school_devices SET building_id=NULL",
    "UPDATE school_devices SET school_id=3",
    "UPDATE school_devices SET state='pending'",
    "UPDATE school_devices SET generation=2",
    "UPDATE school_buildings SET school_id=3",
])
def test_migration_never_guesses_ambiguous_scope(old_registry, change):
    db, migration = old_registry
    db.execute(text(change))
    migration.upgrade()
    assert db.execute(text('SELECT COUNT(*) FROM building_endpoints')).scalar_one() == 0
    assert db.execute(text('SELECT COUNT(*) FROM students')).scalar_one() == 1


@pytest.mark.parametrize('change', [
    "UPDATE building_endpoints SET generation=4",
    "INSERT INTO building_endpoints (school_id,building_id,slug,generation) VALUES (2,2,'2036-2',0)",
])
def test_downgrade_refuses_dropping_new_routes_before_any_ddl(old_registry, change):
    db, migration = old_registry
    migration.upgrade()
    db.execute(text(change))
    with pytest.raises(RuntimeError, match='explicit rollback'):
        migration.downgrade()
    assert 'building_endpoints' in inspect(db).get_table_names()
    assert 'building_login_directory_entries' in inspect(db).get_table_names()
    assert db.execute(text('SELECT COUNT(*) FROM students')).scalar_one() == 1
