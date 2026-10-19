"""Local-only retention. Dry-run by default; no timer is enabled by this module."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sqlite3
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.config.database import SessionLocal
from app.config.settings import settings
from app.repositories.retention_repository import RetentionRepository
from app.services.retention_service import RetentionService, one_year_before
from scripts import local_node

ARCHIVE = re.compile(r'school-(\d{8}T\d{6}Z)\.gbou')


def _archive_time(path):
    match = ARCHIVE.fullmatch(path.name)
    if match is None:
        return None
    try:
        return datetime.strptime(match[1], '%Y%m%dT%H%M%SZ').replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _fingerprint(info):
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_mode


def _root(mount):
    if mount.is_symlink() or not mount.is_dir():
        raise ValueError('Нужен обычный каталог USB, не символическая ссылка')
    root = mount.resolve(strict=True)
    if root == Path(root.anchor):
        raise ValueError('Корень файловой системы не может быть каталогом ротации')
    return root


def expired_archives(mount, now):
    """Only direct managed files; copied/touched/unknown files are preserved."""
    root = _root(mount)
    cutoff = one_year_before(now)
    candidates = []
    for entry in root.iterdir():
        info = entry.lstat()
        created = _archive_time(entry)
        if (stat.S_ISREG(info.st_mode) and created is not None and created < cutoff
                and datetime.fromtimestamp(info.st_mtime, timezone.utc) < cutoff):
            descriptor = os.open(entry, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
            with os.fdopen(descriptor, 'rb') as stream:
                if _fingerprint(os.fstat(stream.fileno())) != _fingerprint(info):
                    raise ValueError('Архив изменился во время проверки')
                if stream.read(len(local_node.FORMAT)) == local_node.FORMAT:
                    candidates.append((entry, _fingerprint(info)))
    return candidates


def archive_report(mount, now):
    root = _root(mount)
    candidates = {entry for entry, _ in expired_archives(root, now)}
    cutoff = one_year_before(now)
    review = 0
    for entry in root.iterdir():
        created = _archive_time(entry)
        info = entry.lstat()
        if entry not in candidates and (
            not stat.S_ISREG(info.st_mode) or created is None or created > now
            or created < cutoff
        ):
            review += 1
    return {'backups': len(candidates), 'backups_manual_review': review}


def prune_archives(mount, fresh, passphrase, now):
    """Called only after backup+DB transaction. Never deletes the fresh recovery copy."""
    root = _root(mount)
    root_id = (root.stat().st_dev, root.stat().st_ino)
    fresh = fresh.absolute()
    if fresh.parent != root or fresh.is_symlink() or not fresh.is_file():
        raise ValueError('Свежая копия должна находиться непосредственно на USB')
    created = _archive_time(fresh)
    minimum = now.astimezone(timezone.utc) - timedelta(hours=24)
    modified = datetime.fromtimestamp(fresh.stat().st_mtime, timezone.utc)
    if created is None or not minimum <= created <= now or not minimum <= modified <= now + timedelta(minutes=1):
        raise ValueError('До ротации требуется свежая USB-копия с корректной датой')
    fresh_id = _fingerprint(fresh.lstat())
    local_node._verify_encrypted_file(fresh, passphrase)
    removed = 0
    for entry, identity in expired_archives(root, now):
        if (root.stat().st_dev, root.stat().st_ino) != root_id:
            raise ValueError('Резервный носитель изменился во время ротации')
        if _fingerprint(fresh.lstat()) != fresh_id:
            raise ValueError('Проверенная свежая копия изменилась; ротация остановлена')
        if entry.parent != root or entry == fresh or _fingerprint(entry.lstat()) != identity:
            raise ValueError('Архив изменился во время ротации')
        entry.unlink()  # One validated file; no globs, recursion or directory removal.
        removed += 1
    local_node._sync_directory(root)
    return removed


def _require_mounted_usb(mount, database):
    root = _root(mount)
    if not root.is_mount():
        raise ValueError('USB не смонтирован; очистка остановлена')
    if os.name == 'posix' and root.stat().st_dev == database.stat().st_dev:
        raise ValueError('Резервный носитель должен отличаться от SD с базой')
    return root


def _require_synchronized_clock():
    if os.name != 'posix' or subprocess.run(
        ['timedatectl', 'show', '--property=NTPSynchronized', '--value'],
        capture_output=True, text=True, check=True,
    ).stdout.strip() != 'yes':
        raise ValueError('До очистки необходимо синхронизировать часы Raspberry (NTP)')


@contextmanager
def _session(database, apply):
    if apply:
        with SessionLocal() as db:
            yield db
        return
    # No production-engine connect hooks/journal-mode changes in a dry-run.
    readonly = create_engine('sqlite://', creator=lambda: sqlite3.connect(
        database.resolve().as_uri() + '?mode=ro', uri=True,
    ))
    try:
        with Session(bind=readonly) as db:
            yield db
    finally:
        readonly.dispose()


def main():
    parser = argparse.ArgumentParser(description='Годовой срок: сначала dry-run, только локальная школа')
    parser.add_argument('--school-id', type=int, required=True)
    parser.add_argument('--mount', type=Path, default=Path('/mnt/gbou-backup'))
    parser.add_argument('--passphrase-file', type=Path, default=Path('/etc/gbou-local/backup.passphrase'))
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--confirm-school-id', type=int)
    args = parser.parse_args()
    if settings.deployment_mode != 'local':
        raise ValueError('Очистка разрешена только на локальной Raspberry, не в облаке')
    database = local_node._sqlite_path()
    if database.is_symlink() or not database.is_file():
        raise ValueError('Рабочая SQLite не найдена или является символической ссылкой')
    root = _require_mounted_usb(args.mount, database)
    now = datetime.now(timezone.utc)
    if args.apply:
        if args.confirm_school_id != args.school_id:
            raise ValueError('Для применения нужен совпадающий --confirm-school-id')
        _require_synchronized_clock()
    with _session(database, args.apply) as db:
        service = RetentionService(RetentionRepository(db), settings.deployment_mode)
        report = service.run(args.school_id, now)  # Scope validation before backup or deletion.
        report.update(archive_report(root, now))
        if args.apply:
            fresh = local_node.backup_usb(root, args.passphrase_file)
            # backup_usb checked owner-only permissions/length and authenticated the snapshot.
            secret = args.passphrase_file.read_text(encoding='utf8').strip()
            report = service.run(args.school_id, now, apply=True)
            report['backups'] = prune_archives(root, fresh, secret, datetime.now(timezone.utc))
            report['backups_manual_review'] = archive_report(root, datetime.now(timezone.utc))['backups_manual_review']
        print(json.dumps(report))  # Counts only: no names, credentials or record bodies.


if __name__ == '__main__':
    main()
