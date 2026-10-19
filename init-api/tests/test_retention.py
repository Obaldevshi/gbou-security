"""Temporary databases/files only. No live school or mounted USB is used."""
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path

import pytest
from cryptography.exceptions import InvalidTag
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

import app.models
from app.models import Base, School, SchoolBuilding, SchoolClass, Student, User, UserRole, ExitRequest, ExitRequestStatus, ExitReasonType, AuditLog
from app.repositories.retention_repository import RetentionRepository
from app.services.retention_service import RetentionService, one_year_before
from scripts import local_node, retention

NOW = datetime(2026, 10, 19, 12, tzinfo=timezone.utc)
OLD = datetime(2024, 1, 1)
SECRET = 'synthetic-only-retention-key-123456'


@pytest.fixture
def db(tmp_path):
    engine = create_engine('sqlite:///' + (tmp_path / 'retention.sqlite').as_posix())
    @event.listens_for(engine, 'connect')
    def foreign_keys(connection, _):
        connection.execute('PRAGMA foreign_keys=ON')
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        db.add(School(id=1, full_name='Synthetic', short_name='Demo', address='Demo'))
        db.flush()
        db.add(SchoolBuilding(id=1, school_id=1, name='Demo', address='Demo'))
        db.flush()
        db.add(SchoolClass(id=1, school_id=1, building_id=1, name='5А'))
        db.add(User(id=1, school_id=1, login='synthetic', full_name='Synthetic teacher', role=UserRole.TEACHER, hashed_password='unused'))
        db.flush()
        db.add(Student(id=1, school_id=1, class_id=1, last_name='Demo', first_name='Pupil'))
        db.commit()
        yield db
    engine.dispose()


def request(db, id, **changes):
    values = dict(id=id, school_id=1, building_id=1, class_id=1, student_id=1, teacher_id=1,
                  reason_type=ExitReasonType.PARENT_NOTE, status=ExitRequestStatus.RELEASED,
                  scheduled_at=OLD, created_at=OLD, updated_at=OLD, released_at=OLD)
    values.update(changes)
    db.add(ExitRequest(**values))


def test_calendar_year_and_exact_boundary():
    assert one_year_before(datetime(2024, 2, 29, 15, tzinfo=timezone.utc)) == datetime(2023, 2, 28, 15, tzinfo=timezone.utc)
    assert one_year_before(NOW) == datetime(2025, 10, 19, 12, tzinfo=timezone.utc)
    with pytest.raises(ValueError):
        one_year_before(datetime(2026, 10, 19))


def test_dry_run_and_apply_preserve_active_future_recent_boundary_and_people(db):
    recent = NOW.replace(tzinfo=None) - timedelta(days=10)
    request(db, 1)
    request(db, 2, status=ExitRequestStatus.PENDING)
    request(db, 3, scheduled_at=recent)
    request(db, 4, updated_at=recent)
    request(db, 5, released_at=recent)
    request(db, 6, created_at=one_year_before(NOW).replace(tzinfo=None))
    request(db, 7, status=ExitRequestStatus.CANCELLED, released_at=None)
    request(db, 8, scheduled_at=NOW.replace(tzinfo=None) + timedelta(days=1))
    db.add_all([AuditLog(school_id=1, method='GET', path='/synthetic', status_code=200, created_at=OLD),
                AuditLog(school_id=1, method='GET', path='/synthetic', status_code=200, created_at=recent),
                AuditLog(school_id=None, method='GET', path='/synthetic', status_code=200, created_at=OLD)])
    db.commit()
    service = RetentionService(RetentionRepository(db), 'local')
    assert service.run(1, NOW)['requests'] == 2
    assert service.run(1, NOW)['audit'] == 1
    assert db.query(ExitRequest).count() == 8
    report = service.run(1, NOW, apply=True)
    assert report['requests'] == 2 and report['audit'] == 1 and not report['dry_run']
    assert {item.id for item in db.query(ExitRequest)} == {2, 3, 4, 5, 6, 8}
    assert db.query(User).count() == db.query(Student).count() == db.query(SchoolClass).count() == 1
    assert db.query(AuditLog).count() == 2


@pytest.mark.parametrize('mode', ['cloud', 'legacy'])
def test_cloud_never_deleted(db, mode):
    request(db, 1); db.commit()
    with pytest.raises(ValueError):
        RetentionService(RetentionRepository(db), mode).run(1, NOW, apply=True)
    assert db.query(ExitRequest).count() == 1


def test_other_or_multiple_schools_fail_closed(db):
    service = RetentionService(RetentionRepository(db), 'local')
    with pytest.raises(ValueError): service.run(2, NOW, apply=True)
    db.add(School(id=2, full_name='Other', short_name='Other', address='Other')); db.commit()
    with pytest.raises(ValueError): service.run(1, NOW, apply=True)


def test_failed_commit_rolls_back(db, monkeypatch):
    request(db, 1); db.commit()
    repo = RetentionRepository(db)
    def fail(): raise RuntimeError('synthetic commit failure')
    monkeypatch.setattr(repo, 'commit', fail)
    with pytest.raises(RuntimeError): RetentionService(repo, 'local').run(1, NOW, apply=True)
    assert db.query(ExitRequest).count() == 1


def test_cli_backup_failure_cannot_delete_records(db, tmp_path, monkeypatch):
    from contextlib import contextmanager
    import sys
    request(db, 1); db.commit()
    @contextmanager
    def session(): yield db
    monkeypatch.setattr(retention, 'SessionLocal', session)
    monkeypatch.setattr(retention.settings, 'deployment_mode', 'local')
    path = Path(db.get_bind().url.database)
    monkeypatch.setattr(local_node, '_sqlite_path', lambda: path)
    monkeypatch.setattr(retention, '_require_mounted_usb', lambda *_: tmp_path)
    monkeypatch.setattr(retention, '_require_synchronized_clock', lambda: None)
    def fail(*_): raise ValueError('synthetic backup failure')
    monkeypatch.setattr(local_node, 'backup_usb', fail)
    monkeypatch.setattr(sys, 'argv', ['retention', '--school-id', '1', '--apply', '--confirm-school-id', '1'])
    with pytest.raises(ValueError, match='synthetic backup failure'): retention.main()
    assert db.query(ExitRequest).count() == 1


def test_preview_connection_is_database_read_only(db):
    from sqlalchemy import text
    from sqlalchemy.exc import OperationalError
    request(db, 1); db.commit()
    with retention._session(Path(db.get_bind().url.database), False) as readonly:
        assert RetentionService(RetentionRepository(readonly), 'local').run(1, NOW)['requests'] == 1
        with pytest.raises(OperationalError): readonly.execute(text('DELETE FROM exit_requests'))
    assert db.query(ExitRequest).count() == 1


def archive(folder, when, *, content=None, modified=None):
    output = folder / f'school-{when:%Y%m%dT%H%M%SZ}.gbou'
    output.write_bytes(local_node._seal(b'synthetic snapshot', SECRET) if content is None else content)
    moment = (modified or when).timestamp()
    os.utime(output, (moment, moment))
    return output


def test_usb_prunes_only_expired_managed_files_and_preserves_recovery(tmp_path):
    now = datetime.now(timezone.utc)
    cutoff = one_year_before(now)
    old = archive(tmp_path, cutoff - timedelta(days=2))
    copied = archive(tmp_path, cutoff - timedelta(days=3), modified=now)
    plain = archive(tmp_path, cutoff - timedelta(days=4), content=b'not a managed encrypted backup')
    unknown = tmp_path / 'keep.gbou'; unknown.write_bytes(b'KEEP')
    future = archive(tmp_path, now + timedelta(days=1))
    fresh = archive(tmp_path, now)
    assert len(retention.expired_archives(tmp_path, now)) == 1
    assert retention.archive_report(tmp_path, now) == {'backups': 1, 'backups_manual_review': 4}
    assert old.exists()  # Selection/dry-run is read-only.
    assert retention.prune_archives(tmp_path, fresh, SECRET, now) == 1
    assert not old.exists()
    assert all(item.exists() for item in [copied, plain, unknown, future, fresh])


def test_damaged_or_missing_fresh_backup_blocks_pruning(tmp_path):
    now = datetime.now(timezone.utc)
    old = archive(tmp_path, one_year_before(now) - timedelta(days=1))
    fresh = archive(tmp_path, now)
    damaged = bytearray(fresh.read_bytes()); damaged[-1] ^= 1; fresh.write_bytes(damaged)
    with pytest.raises(InvalidTag): retention.prune_archives(tmp_path, fresh, SECRET, now)
    assert old.exists()
    with pytest.raises(ValueError): retention.prune_archives(tmp_path, tmp_path/'missing.gbou', SECRET, now)
    assert old.exists()


def test_no_fresh_snapshot_means_no_rotation(tmp_path):
    now = datetime.now(timezone.utc)
    old = archive(tmp_path, one_year_before(now) - timedelta(days=1))
    with pytest.raises(ValueError): retention.prune_archives(tmp_path, old, SECRET, now)
    assert old.exists()


def test_symlinks_and_outside_fresh_file_are_not_followed(tmp_path):
    now = datetime.now(timezone.utc)
    usb = tmp_path/'usb'; usb.mkdir()
    outside = archive(tmp_path, one_year_before(now) - timedelta(days=1))
    link = usb/outside.name
    try: link.symlink_to(outside)
    except OSError: pytest.skip('OS does not permit symlinks in temporary directory')
    assert retention.expired_archives(usb, now) == []
    with pytest.raises(ValueError): retention.prune_archives(usb, outside, SECRET, now)
    fresh = archive(usb, now)
    assert retention.prune_archives(usb, fresh, SECRET, now) == 0
    assert outside.exists() and link.is_symlink()
