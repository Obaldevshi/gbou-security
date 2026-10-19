"""One-school transfer and encrypted USB snapshots for a Raspberry Pi node.

Run as ``python -m scripts.local_node <command>`` with the API environment set.
No command removes rows from the central database.
"""

import argparse
from contextlib import closing
import getpass
import json
import os
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from sqlalchemy import DateTime, Table, insert, select
from sqlalchemy.engine import make_url

from app.config.database import Base, engine
from app.config.settings import settings
import app.models  # noqa: F401 - register all ORM tables

FORMAT = b"GBOU-LOCAL-1\n"
SCHEMA_VERSION = 1
ORDER = (
    "schools", "school_buildings", "users", "school_classes", "students",
    "teacher_class_assignments", "categories", "exit_requests", "audit_logs",
)


def _sqlite_path() -> Path:
    url = make_url(settings.database_url)
    path = Path(url.database or "")
    if url.get_backend_name() != "sqlite" or not path.is_absolute():
        raise ValueError("Для локальной базы нужен абсолютный DATABASE_URL=sqlite:////...")
    return path


def _sync_directory(path: Path) -> None:
    # Windows cannot open a directory descriptor; installation targets Linux.
    if os.name == "posix":
        descriptor = os.open(path, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def _derive_key(passphrase: str, salt: bytes) -> bytes:
    return Scrypt(salt=salt, length=32, n=2**15, r=8, p=1).derive(passphrase.encode())


def _seal(payload: bytes, passphrase: str) -> bytes:
    salt, nonce = os.urandom(16), os.urandom(12)
    return FORMAT + salt + nonce + AESGCM(_derive_key(passphrase, salt)).encrypt(nonce, payload, FORMAT)


def _open(blob: bytes, passphrase: str) -> bytes:
    if not blob.startswith(FORMAT) or len(blob) < len(FORMAT) + 44:
        raise ValueError("Неизвестный формат зашифрованного архива")
    offset = len(FORMAT)
    salt, nonce = blob[offset:offset + 16], blob[offset + 16:offset + 28]
    return AESGCM(_derive_key(passphrase, salt)).decrypt(nonce, blob[offset + 28:], FORMAT)


def _write_private(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".gbou-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            os.chmod(temporary, 0o600)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)  # Publish exclusively; never overwrite an archive.
        _sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _encrypt_file(source: Path, destination: Path, passphrase: str) -> None:
    """Stream a SQLite snapshot into AES-GCM without holding it in RAM."""
    salt, nonce = os.urandom(16), os.urandom(12)
    header = FORMAT + salt + nonce
    encryptor = Cipher(algorithms.AES(_derive_key(passphrase, salt)), modes.GCM(nonce)).encryptor()
    encryptor.authenticate_additional_data(FORMAT)
    descriptor, temporary = tempfile.mkstemp(prefix=".gbou-", dir=destination.parent)
    try:
        with source.open("rb") as input_stream, os.fdopen(descriptor, "wb") as output_stream:
            os.chmod(temporary, 0o600)
            output_stream.write(header)
            while chunk := input_stream.read(1024 * 1024):
                output_stream.write(encryptor.update(chunk))
            output_stream.write(encryptor.finalize())
            output_stream.write(encryptor.tag)
            output_stream.flush()
            os.fsync(output_stream.fileno())
        os.link(temporary, destination)
        _sync_directory(destination.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _decrypt_file(source: Path, destination: Path, passphrase: str) -> None:
    if destination.exists():
        raise FileExistsError("Файл назначения уже существует")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as input_stream:
        header = input_stream.read(len(FORMAT) + 28)
        if not header.startswith(FORMAT) or len(header) != len(FORMAT) + 28:
            raise ValueError("Неизвестный формат зашифрованного архива")
        input_stream.seek(0, os.SEEK_END)
        size = input_stream.tell()
        if size < len(header) + 16:
            raise ValueError("Архив обрезан")
        input_stream.seek(size - 16)
        tag = input_stream.read(16)
        salt = header[len(FORMAT):len(FORMAT) + 16]
        nonce = header[len(FORMAT) + 16:]
        decryptor = Cipher(algorithms.AES(_derive_key(passphrase, salt)), modes.GCM(nonce, tag)).decryptor()
        decryptor.authenticate_additional_data(FORMAT)
        input_stream.seek(len(header))
        remaining = size - len(header) - 16
        descriptor, temporary = tempfile.mkstemp(prefix=".gbou-", dir=destination.parent)
        try:
            with os.fdopen(descriptor, "wb") as output_stream:
                os.chmod(temporary, 0o600)
                while remaining:
                    chunk = input_stream.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("Архив обрезан")
                    remaining -= len(chunk)
                    output_stream.write(decryptor.update(chunk))
                output_stream.write(decryptor.finalize())
                output_stream.flush()
                os.fsync(output_stream.fileno())
            os.link(temporary, destination)
            _sync_directory(destination.parent)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def _verify_encrypted_file(source: Path, passphrase: str) -> None:
    """Verify the USB ciphertext/tag without a second SD-card copy."""
    with source.open("rb") as stream:
        header = stream.read(len(FORMAT) + 28)
        if not header.startswith(FORMAT) or len(header) != len(FORMAT) + 28:
            raise ValueError("Зашифрованная копия имеет неверный заголовок")
        stream.seek(0, os.SEEK_END)
        size = stream.tell()
        if size < len(header) + 16:
            raise ValueError("Зашифрованная копия обрезана")
        stream.seek(size - 16)
        tag = stream.read(16)
        salt = header[len(FORMAT):len(FORMAT) + 16]
        nonce = header[len(FORMAT) + 16:]
        decryptor = Cipher(algorithms.AES(_derive_key(passphrase, salt)), modes.GCM(nonce, tag)).decryptor()
        decryptor.authenticate_additional_data(FORMAT)
        stream.seek(len(header))
        remaining = size - len(header) - 16
        while remaining:
            chunk = stream.read(min(1024 * 1024, remaining))
            if not chunk:
                raise ValueError("Зашифрованная копия обрезана")
            remaining -= len(chunk)
            decryptor.update(chunk)
        decryptor.finalize()


def _passphrase(confirm: bool = False) -> str:
    value = getpass.getpass("Пароль архива (сохраните отдельно от Raspberry): ")
    if len(value) < 16:
        raise ValueError("Пароль архива должен содержать минимум 16 символов")
    if confirm and value != getpass.getpass("Повторите пароль: "):
        raise ValueError("Пароли архива не совпали")
    return value


def _encode_row(row) -> dict:
    return {
        key: {"datetime": value.isoformat()} if isinstance(value, datetime) else value
        for key, value in row._mapping.items()
    }


def _decode_row(table: Table, row: dict) -> dict:
    return {
        key: datetime.fromisoformat(value["datetime"])
        if isinstance(table.c[key].type, DateTime) and isinstance(value, dict)
        else value
        for key, value in row.items()
    }


def collect_school(school_id: int) -> dict:
    """Read a consistent, school-scoped snapshot without changing the source."""
    if settings.deployment_mode == "local":
        raise ValueError("Экспорт выполняется на сервере с центральной базой")
    tables = Base.metadata.tables
    data = {}
    with engine.connect() as connection:
        transaction = connection.begin()
        try:
            if connection.dialect.name == "postgresql":
                connection.exec_driver_sql("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            school = connection.execute(select(tables["schools"]).where(tables["schools"].c.id == school_id)).first()
            if school is None:
                raise ValueError("Школа не найдена")
            users = tables["users"]
            user_ids = [row[0] for row in connection.execute(select(users.c.id).where(users.c.school_id == school_id))]
            for name in ORDER:
                table = tables[name]
                if name == "schools":
                    condition = table.c.id == school_id
                elif name in {"teacher_class_assignments", "categories"}:
                    condition = table.c.teacher_id.in_(user_ids) if name == "teacher_class_assignments" else table.c.user_id.in_(user_ids)
                else:
                    condition = table.c.school_id == school_id
                rows = [_encode_row(row) for row in connection.execute(select(table).where(condition).order_by(table.c.id))]
                if name == "audit_logs":
                    for row in rows:
                        if row["actor_id"] not in user_ids:
                            row["actor_id"] = None
                data[name] = rows
        finally:
            transaction.rollback()
    return {"schema": SCHEMA_VERSION, "school_id": school_id, "rows": data}


def export_school(school_id: int, destination: Path) -> None:
    document = collect_school(school_id)
    payload = json.dumps(document, ensure_ascii=False).encode()
    if destination.exists():
        raise FileExistsError("Архив уже существует; выберите новое имя")
    _write_private(destination, _seal(payload, _passphrase(confirm=True)))
    print("Зашифрованный архив создан; исходная база не изменена.")
    print(json.dumps({name: len(rows) for name, rows in document["rows"].items()}, ensure_ascii=False))


def init_local() -> None:
    if settings.deployment_mode != "local":
        raise ValueError("Инициализация разрешена только в DEPLOYMENT_MODE=local")
    path = _sqlite_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(path)) as db:
        db.execute("CREATE TABLE IF NOT EXISTS local_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        existing = db.execute("SELECT value FROM local_meta WHERE key='schema_version'").fetchone()
        if existing and existing[0] != str(SCHEMA_VERSION):
            raise ValueError("Версия локальной схемы не совпадает; необходима миграция")
    Base.metadata.create_all(engine)
    with closing(sqlite3.connect(path)) as db:
        db.execute("INSERT OR IGNORE INTO local_meta VALUES ('schema_version', ?)", (str(SCHEMA_VERSION),))
        db.commit()
    os.chmod(path, 0o600)
    print(f"Локальная база подготовлена: {path}")


def _validate_school_archive(document: dict) -> None:
    if document.get("schema") != SCHEMA_VERSION:
        raise ValueError("Версия архива не поддерживается")
    rows = document.get("rows", {})
    if set(rows) != set(ORDER) or len(rows["schools"]) != 1:
        raise ValueError("Архив содержит неполную схему школы")
    school_id = document.get("school_id")
    if rows["schools"][0]["id"] != school_id:
        raise ValueError("Идентификатор школы в архиве не совпадает")
    ids = {}
    for name in ORDER:
        ids[name] = {row["id"] for row in rows[name]}
        if len(ids[name]) != len(rows[name]):
            raise ValueError(f"Повторяющиеся ID в таблице {name}")
        for row in rows[name]:
            if "school_id" in row and row["school_id"] != school_id:
                raise ValueError("Архив содержит данные другой школы")
            if not set(row).issubset(Base.metadata.tables[name].c.keys()):
                raise ValueError(f"Неизвестные поля в таблице {name}")
    for user in rows["users"]:
        if user["role"] not in {"school_admin", "teacher", "guard"}:
            raise ValueError("Учётная запись главного администратора не переносится локально")
    for name in ORDER:
        table = Base.metadata.tables[name]
        for row in rows[name]:
            for foreign_key in table.foreign_keys:
                value = row.get(foreign_key.parent.name)
                if value is not None and value not in ids[foreign_key.column.table.name]:
                    raise ValueError(f"Связь {name}.{foreign_key.parent.name} выходит за пределы школы")


def import_school(source: Path) -> None:
    import_document(json.loads(_open(source.read_bytes(), _passphrase())))


def import_document(document: dict) -> None:
    """Import a validated document into an empty local database only."""
    if settings.deployment_mode != "local":
        raise ValueError("Импорт разрешён только в DEPLOYMENT_MODE=local")
    _validate_school_archive(document)
    init_local()
    with engine.begin() as connection:
        if any(connection.execute(select(table.c.id).limit(1)).first()
               for table in Base.metadata.tables.values()):
            raise ValueError("Локальная база уже содержит школу; импорт в непустую базу запрещён")
        for name in ORDER:
            table = Base.metadata.tables[name]
            rows = [_decode_row(table, row) for row in document["rows"][name]]
            if rows:
                connection.execute(insert(table), rows)
        if connection.exec_driver_sql('PRAGMA foreign_key_check').first():
            raise RuntimeError('В импортированной базе нарушены связи записей')
        if settings.gbou_building_id is not None:
            from app.core.building_scope import validate_building_database
            validate_building_database(connection, settings.gbou_building_id, document['school_id'])
    with closing(sqlite3.connect(_sqlite_path())) as db:
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise RuntimeError("Проверка целостности локальной базы не пройдена")
    print("Данные одной школы перенесены. Все старые доверенные сессии потребуют нового входа.")
    print(json.dumps({name: len(rows) for name, rows in document["rows"].items()}, ensure_ascii=False))


def backup_usb(mount: Path, passphrase_file: Path) -> Path:
    if settings.deployment_mode != "local":
        raise ValueError("Резервирование разрешено только на локальном узле")
    if not mount.is_mount():
        raise ValueError("USB-флешка не смонтирована; копия на SD-карту запрещена")
    path = _sqlite_path()
    if not path.is_file():
        raise FileNotFoundError("Локальная база не найдена")
    # ReadWritePaths in systemd may make an ordinary SD directory a bind mount.
    # is_mount alone is therefore insufficient: backup must use another device.
    if os.name == 'posix' and mount.stat().st_dev == path.stat().st_dev:
        raise ValueError("Резервный носитель находится на той же файловой системе, что и SD-база")
    if os.name == "posix" and passphrase_file.stat().st_mode & 0o077:
        raise PermissionError("Файл пароля резервной копии должен быть доступен только владельцу (0600)")
    secret = passphrase_file.read_text(encoding="utf-8").strip()
    if len(secret) < 16:
        raise ValueError("Файл пароля архива пустой или слишком короткий")
    with tempfile.TemporaryDirectory() as temporary:
        snapshot = Path(temporary) / "snapshot.sqlite3"
        with closing(sqlite3.connect(f"file:{path}?mode=ro", uri=True)) as source, closing(sqlite3.connect(snapshot)) as target:
            source.backup(target)
        with closing(sqlite3.connect(snapshot)) as check:
            if check.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise RuntimeError("Копия базы повреждена")
            if check.execute('PRAGMA foreign_key_check').fetchone():
                raise RuntimeError('В копии базы нарушены связи записей')
        name = f"school-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.gbou"
        output = mount / name
        if output.exists():
            raise FileExistsError("Копия за эту секунду уже существует")
        _encrypt_file(snapshot, output, secret)
        _verify_encrypted_file(output, secret)
    with closing(sqlite3.connect(path, timeout=30)) as db:
        db.execute(
            "INSERT INTO local_meta (key, value) VALUES ('last_backup_verified', ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (datetime.now(timezone.utc).isoformat(),),
        )
        db.commit()
    print(f"Зашифрованная и проверенная USB-копия: {output}")
    return output


def restore_to_file(source: Path, destination: Path) -> None:
    """Decrypt into a NEW file; never replace the running school database."""
    if destination.exists():
        raise FileExistsError("Файл назначения уже существует")
    _decrypt_file(source, destination, _passphrase())
    try:
        with destination.open("rb") as restored:
            if restored.read(16) != b"SQLite format 3\0":
                raise ValueError("Архив не содержит базу SQLite")
        with closing(sqlite3.connect(f"file:{destination}?mode=ro", uri=True)) as db:
            if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise RuntimeError("База в архиве повреждена")
            if db.execute('PRAGMA foreign_key_check').fetchone():
                raise RuntimeError('В восстановленной базе нарушены связи записей')
    except Exception:
        destination.unlink()
        raise
    print(f"Проверенная копия восстановлена в отдельный файл: {destination}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Локальная база школы и USB-копии")
    sub = parser.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export-school")
    export.add_argument("--school-id", type=int, required=True)
    export.add_argument("--out", type=Path, required=True)
    sub.add_parser("init")
    import_parser = sub.add_parser("import-school")
    import_parser.add_argument("--in", dest="source", type=Path, required=True)
    backup = sub.add_parser("backup-usb")
    backup.add_argument("--mount", type=Path, default=Path("/mnt/gbou-backup"))
    backup.add_argument("--passphrase-file", type=Path, default=Path("/etc/gbou-local/backup.passphrase"))
    restore = sub.add_parser("restore-to-file")
    restore.add_argument("--in", dest="source", type=Path, required=True)
    restore.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "export-school":
        export_school(args.school_id, args.out)
    elif args.command == "init":
        init_local()
    elif args.command == "import-school":
        import_school(args.source)
    elif args.command == "backup-usb":
        backup_usb(args.mount, args.passphrase_file)
    else:
        restore_to_file(args.source, args.out)


if __name__ == "__main__":
    main()
