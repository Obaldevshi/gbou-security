"""Provision a per-school node key centrally, or sync its local mirror.

With explicit directory opt-in, only login digests are sent for routing.
No source logins, names, student records or credentials are exported.
"""

import argparse
import hashlib
import os
import secrets
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import httpx
from sqlalchemy import text

from app.config.database import SessionLocal
from app.config.settings import settings
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_node_credential import SchoolNodeCredential
from app.models.trusted_device_session import TrustedDeviceSession
from app.models.user import User, UserRole
from app.schemas.node_config import NodeConfigEnvelope


def _private_file(path: Path, content: str) -> None:
    if path.exists():
        raise FileExistsError("Файл ключа уже существует")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".gbou-node-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            os.chmod(temporary, 0o600)
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def provision(school_id: int, output: Path) -> None:
    if settings.deployment_mode == "local":
        raise ValueError("Ключ создаётся только в центральном сервисе")
    token = secrets.token_urlsafe(48)
    digest = hashlib.sha256(token.encode()).hexdigest()
    created_file = False
    try:
        with SessionLocal.begin() as db:
            if db.get(School, school_id) is None:
                raise ValueError("Школа не найдена")
            credential = db.query(SchoolNodeCredential).filter(SchoolNodeCredential.school_id == school_id).first()
            _private_file(output, token + "\n")
            created_file = True
            if credential is None:
                db.add(SchoolNodeCredential(school_id=school_id, token_hash=digest, is_active=True))
            else:
                credential.token_hash = digest
                credential.is_active = True
    except Exception:
        if created_file and output.exists():
            output.unlink()
        raise
    print(f"Ключ школы {school_id} записан в {output}. Передайте его на Raspberry защищённо.")
    print("Ротация немедленно делает прежний ключ недействительным для следующей синхронизации.")


def revoke(school_id: int) -> None:
    if settings.deployment_mode == "local":
        raise ValueError("Ключ отзывается только в центральном сервисе")
    with SessionLocal.begin() as db:
        credential = db.query(SchoolNodeCredential).filter(
            SchoolNodeCredential.school_id == school_id
        ).first()
        if credential is None:
            raise ValueError("Для этой школы ключ узла не выдавался")
        credential.is_active = False
    print(f"Ключ узла школы {school_id} отозван. Локальный узел больше не получит обновления.")


def _read_token(path: Path) -> str:
    if os.name == "posix" and path.stat().st_mode & 0o077:
        raise PermissionError("Файл ключа узла должен иметь права 0600")
    token = path.read_text(encoding="utf-8").strip()
    if len(token) < 40:
        raise ValueError("Ключ узла отсутствует или слишком короткий")
    return token


def validate_building_snapshot(snapshot, expected_building):
    """Refuse scope changes before opening a write transaction. Never prune a
    multi-building database as a side effect of receiving a narrower snapshot.
    """
    if expected_building is not None or snapshot.building_id is not None:
        if (expected_building is None or expected_building <= 0
                or snapshot.building_id != expected_building
                or [item.id for item in snapshot.buildings] != [expected_building]):
            raise ValueError('Конфигурация относится к другому корпусу; сначала проверьте привязку')


def sync(*, enroll_empty: bool = False) -> None:
    if settings.deployment_mode != "local":
        raise ValueError("Синхронизация запускается только на локальном узле")
    base_url = os.environ.get("GBOU_CLOUD_API_BASE", "").rstrip("/")
    school_id = int(os.environ.get("GBOU_SCHOOL_ID", "0"))
    token_file = Path(os.environ.get("GBOU_NODE_TOKEN_FILE", "/etc/gbou-local/node.token"))
    if not base_url.startswith("https://") or school_id <= 0:
        raise ValueError("Укажите HTTPS GBOU_CLOUD_API_BASE и GBOU_SCHOOL_ID")
    token = _read_token(token_file)
    response = httpx.get(
        f"{base_url}/node/config",
        headers={"X-School-Node-Token": token, "Accept": "application/json"},
        timeout=15,
        follow_redirects=False,
    )
    response.raise_for_status()
    snapshot = NodeConfigEnvelope.model_validate(response.json()).data
    if snapshot.school.id != school_id:
        raise ValueError("Получена конфигурация другой школы")
    if any(item.school_id != school_id for item in snapshot.buildings + snapshot.school_admins):
        raise ValueError("Конфигурация содержит запись другой школы")
    if len({item.id for item in snapshot.buildings}) != len(snapshot.buildings):
        raise ValueError("В конфигурации повторяются корпуса")
    if len({item.id for item in snapshot.school_admins}) != len(snapshot.school_admins):
        raise ValueError("В конфигурации повторяются администраторы")
    building_scope = int(os.environ['GBOU_BUILDING_ID']) if os.environ.get('GBOU_BUILDING_ID') else None
    validate_building_snapshot(snapshot, building_scope)

    with SessionLocal.begin() as db:
        school = db.get(School, school_id)
        if db.query(School.id).filter(School.id != school_id).first():
            raise ValueError("Локальный узел должен содержать только одну школу")
        if building_scope is not None and db.query(SchoolBuilding.id).filter(
                (SchoolBuilding.id != building_scope) | (SchoolBuilding.school_id != school_id)).first():
            raise ValueError('В базе есть другой корпус. Нужна отдельная проверенная миграция, а не sync')
        if school is not None and building_scope is not None:
            from app.core.building_scope import validate_building_database
            validate_building_database(db.connection(), building_scope, school_id)
        if school is None and enroll_empty:
            school = School(id=school_id, **snapshot.school.model_dump(exclude={"id"}))
            db.add(school)
            db.flush()
        if school is None:
            raise ValueError("Сначала перенесите данные школы в пустой локальный узел")
        for field in ("full_name", "short_name", "address", "is_active"):
            setattr(school, field, getattr(snapshot.school, field))

        seen_buildings = set()
        for remote in snapshot.buildings:
            building = db.get(SchoolBuilding, remote.id)
            if building is None:
                building = SchoolBuilding(id=remote.id, school_id=school_id)
                db.add(building)
            elif building.school_id != school_id:
                raise ValueError("ID корпуса занят другой школой")
            building.name = remote.name
            building.address = remote.address
            building.is_active = remote.is_active
            seen_buildings.add(remote.id)
        for building in db.query(SchoolBuilding).filter(SchoolBuilding.school_id == school_id):
            if building.id not in seen_buildings:
                building.is_active = False

        seen_admins = set()
        for remote in snapshot.school_admins:
            marker_key = f"central_admin_hash:{remote.id}"
            previous_central_hash = db.execute(
                text("SELECT value FROM local_meta WHERE key=:key"), {"key": marker_key}
            ).scalar_one_or_none()
            existing = db.get(User, remote.id)
            if existing is not None and (existing.role != UserRole.SCHOOL_ADMIN or existing.school_id != school_id):
                existing = None
            if existing is None:
                existing = db.get(User, -remote.id)
            if existing is None:
                existing = User(
                    id=-remote.id, school_id=school_id, role=UserRole.SCHOOL_ADMIN,
                    login=remote.login, full_name=remote.full_name, phone=remote.phone,
                    hashed_password=remote.hashed_password, is_active=remote.is_active,
                    must_change_password=remote.must_change_password,
                )
                db.add(existing)
            elif existing.role != UserRole.SCHOOL_ADMIN or existing.school_id != school_id:
                raise ValueError("Локальный ID администратора занят другой учётной записью")
            if existing.deleted_at is not None and remote.deleted_at is None:
                # A restored/stale cloud snapshot must not resurrect a deleted mirror.
                seen_admins.add(existing.id)
                continue
            with db.no_autoflush:
                conflict = db.query(User).filter(User.login == remote.login, User.id != existing.id).first()
            if conflict is not None:
                raise ValueError(f"Логин администратора {remote.login} уже используется локально")
            central_password_changed = previous_central_hash is None or previous_central_hash != remote.hashed_password
            if (central_password_changed and existing.hashed_password != remote.hashed_password) or not remote.is_active:
                db.query(TrustedDeviceSession).filter(
                    TrustedDeviceSession.user_id == existing.id,
                    TrustedDeviceSession.revoked_at.is_(None),
                ).update({TrustedDeviceSession.revoked_at: datetime.now(timezone.utc)}, synchronize_session=False)
            existing.login = remote.login
            existing.full_name = remote.full_name
            existing.phone = remote.phone
            if central_password_changed:
                existing.hashed_password = remote.hashed_password
                existing.must_change_password = remote.must_change_password
            existing.is_active = remote.is_active
            if remote.deleted_at is not None:
                from app.repositories.account_deletion_repository import AccountDeletionRepository
                AccountDeletionRepository(db).erase_personal_links(existing)
                existing.deleted_at = remote.deleted_at
                existing.is_active = False
                existing.password_reset_marker = None
                existing.must_change_password = False
            db.execute(
                text("INSERT INTO local_meta (key, value) VALUES (:key, :value) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value"),
                {"key": marker_key, "value": remote.hashed_password},
            )
            seen_admins.add(existing.id)
        for admin in db.query(User).filter(User.school_id == school_id, User.role == UserRole.SCHOOL_ADMIN):
            if admin.id not in seen_admins:
                admin.is_active = False
                db.query(TrustedDeviceSession).filter(
                    TrustedDeviceSession.user_id == admin.id,
                    TrustedDeviceSession.revoked_at.is_(None),
                ).update({TrustedDeviceSession.revoked_at: datetime.now(timezone.utc)}, synchronize_session=False)
        db.execute(
            text("INSERT INTO local_meta (key, value) VALUES ('last_config_sync', :value) "
                 "ON CONFLICT(key) DO UPDATE SET value=excluded.value"),
            {"value": datetime.now(timezone.utc).isoformat()},
        )
    print(f"Конфигурация школы {school_id} обновлена: {len(snapshot.buildings)} корпусов, {len(snapshot.school_admins)} администраторов")
    if settings.login_directory_enabled:
        from scripts.login_directory import publish
        try:
            publish()
        except Exception as error:
            raise SystemExit('Login directory sync failed (' + type(error).__name__ + '); configuration sync completed') from None


def main() -> None:
    parser = argparse.ArgumentParser(description="Центральные настройки локального школьного узла")
    sub = parser.add_subparsers(dest="command", required=True)
    provision_parser = sub.add_parser("provision")
    provision_parser.add_argument("--school-id", type=int, required=True)
    provision_parser.add_argument("--out", type=Path, required=True)
    revoke_parser = sub.add_parser("revoke")
    revoke_parser.add_argument("--school-id", type=int, required=True)
    sub.add_parser("sync")
    sub.add_parser("enroll-empty", help="Подключить новую школу без старых учеников/заявок")
    args = parser.parse_args()
    if args.command == "provision":
        provision(args.school_id, args.out)
    elif args.command == "revoke":
        revoke(args.school_id)
    else:
        sync(enroll_empty=args.command == "enroll-empty")


if __name__ == "__main__":
    main()
