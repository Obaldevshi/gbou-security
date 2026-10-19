"""SQLite and scope invariants only. No Pi paths, services or network used."""
import importlib.util
import json
from pathlib import Path
import sqlite3
import sys
from types import SimpleNamespace
import pytest


@pytest.fixture
def primary(monkeypatch, tmp_path):
    # Linux-only account lookup is injected, never consult a real kiosk account.
    monkeypatch.setitem(sys.modules, 'pwd', SimpleNamespace(getpwnam=lambda _: SimpleNamespace(pw_dir=str(tmp_path))))
    source = Path(__file__).parents[1] / 'local-node/rebind_primary.py'
    spec = importlib.util.spec_from_file_location('isolated_primary', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.SCHOOL_ID = 2
    module.BUILDING_ID = 1
    module.ROOT = tmp_path / 'operations'
    module.ROOT.mkdir()
    module.MARKER = module.ROOT / 'in-progress'
    module.DB = tmp_path / 'live' / 'school.sqlite3'
    monkeypatch.setattr(module, 'run', lambda *a: pytest.fail('No real system command permitted'))
    return module


def database(path, school_id=2):
    with sqlite3.connect(path) as db:
        db.executescript('CREATE TABLE schools(id INTEGER PRIMARY KEY); CREATE TABLE school_buildings(id INTEGER PRIMARY KEY, school_id INTEGER); CREATE TABLE students(id INTEGER PRIMARY KEY, is_active INTEGER, deleted_at TEXT); CREATE TABLE local_meta(key TEXT,value TEXT);')
        db.execute('INSERT INTO schools VALUES(?)', (school_id,))
        db.execute('INSERT INTO school_buildings VALUES(1,?)', (school_id,))
        db.execute('INSERT INTO students VALUES(1,1,NULL)')
        db.execute("INSERT INTO local_meta VALUES('sync','synthetic')")
        db.commit()


def test_fingerprint_includes_all_fields_and_operational_metadata(primary, tmp_path):
    path = tmp_path / 'school.sqlite3'
    database(path)
    original = primary.fingerprint(path)
    assert 'local_meta' in original['tables'] and 'students' in original['tables']
    with sqlite3.connect(path) as db:
        db.execute("UPDATE students SET deleted_at='synthetic' WHERE id=1")
        db.commit()
    assert primary.fingerprint(path) != original


def test_foreign_school_database_refused(primary, tmp_path):
    path = tmp_path / 'foreign.sqlite3'
    database(path, school_id=3)
    with pytest.raises(AssertionError):
        primary.fingerprint(path)


def test_same_school_foreign_building_database_refused(primary, tmp_path):
    path = tmp_path / 'other-building.sqlite3'
    database(path)
    with sqlite3.connect(path) as db:
        db.execute('INSERT INTO school_buildings VALUES(2,2)')
        db.commit()
    with pytest.raises(AssertionError):
        primary.fingerprint(path)


def test_hidden_foreign_building_record_refused(primary, tmp_path):
    path = tmp_path / 'foreign-row.sqlite3'
    database(path)
    with sqlite3.connect(path) as db:
        db.executescript('CREATE TABLE school_classes(id INTEGER PRIMARY KEY, school_id INTEGER, building_id INTEGER, is_active INTEGER); INSERT INTO school_classes VALUES(1,2,2,0);')
    with pytest.raises(AssertionError):
        primary.fingerprint(path)


@pytest.mark.parametrize('school,building,role', [(3, 1, 'primary'), (2, 1, 'terminal'), (2, 2, 'primary')])
def test_restore_never_moves_old_data_to_foreign_school_building_or_terminal(primary, monkeypatch, tmp_path, school, building, role):
    monkeypatch.setattr(primary.os, 'geteuid', lambda: 0, raising=False)
    folder = primary.ROOT / 'operation'
    folder.mkdir()
    held = folder / 'school-data'
    held.mkdir()
    path = held / 'school.sqlite3'
    database(path)
    inode = path.stat().st_ino
    state = {'phase': 'qr_ready', 'baseline': primary.fingerprint(path), 'database_inode': inode,
             'old_primary': {'device_id': 'old', 'hostname': '2.gbousecurity.ru'}}
    (folder / 'state.json').write_text(json.dumps(state))
    primary.MARKER.write_text(str(folder))
    device = tmp_path / 'device'
    device.mkdir()
    (device / 'device.json').write_text(json.dumps({'device_id': 'new', 'school_id': school,
                                                  'building_id': building, 'role': role}))
    actual_path = Path
    monkeypatch.setattr(primary, 'Path', lambda value: device if value == '/etc/gbou-device'
                        else tmp_path / 'absent-config' if value == '/etc/gbou-local' else actual_path(value))
    monkeypatch.setattr(primary, 'run', lambda *a: 'inactive')
    with pytest.raises(AssertionError):
        primary.restore_pending()
    assert path.is_file() and path.stat().st_ino == inode
    assert not primary.DB.exists() and primary.MARKER.exists()
