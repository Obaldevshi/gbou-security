"""Reset an existing super administrator from a trusted server terminal only.

Run from the backend directory: python -m scripts.reset_superadmin_password
--login superadmin. Passwords are accepted only through a non-echoing TTY.
"""

import argparse
from datetime import datetime, timezone
import getpass
import secrets
import sys
import warnings

from app.utils.validation import validate_password_strength


class RecoveryError(ValueError):
    """A safe, operator-facing validation message without configuration values."""


def validate_password(password: str) -> None:
    try:
        validate_password_strength(password)
    except ValueError as error:
        raise RecoveryError(str(error)) from None
    # bcrypt hashes at most 72 UTF-8 bytes; never silently truncate a password.
    if len(password.encode("utf-8")) > 72:
        raise RecoveryError("Пароль слишком длинный: допустимо до 72 байт UTF-8")


def reset_password(db, login: str, password: str) -> None:
    from app.core.security import get_password_hash
    from app.models import AuditLog, TrustedDeviceSession, User, UserRole

    validate_password(password)
    try:
        user = (
            db.query(User)
            .filter(User.login == login.strip().lower())
            .with_for_update()
            .one_or_none()
        )
        if user is None or user.role != UserRole.SUPER_ADMIN:
            raise RecoveryError("Главный администратор с таким логином не найден")
        if not user.is_active:
            raise RecoveryError("Учётная запись отключена. Сброс не меняет её права или активность")

        user.hashed_password = get_password_hash(password)
        user.must_change_password = True
        user.password_reset_marker = secrets.token_hex(32)
        db.query(TrustedDeviceSession).filter(
            TrustedDeviceSession.user_id == user.id,
            TrustedDeviceSession.revoked_at.is_(None),
        ).update(
            {TrustedDeviceSession.revoked_at: datetime.now(timezone.utc)},
            synchronize_session=False,
        )
        db.add(AuditLog(
            actor_id=None,  # Server operator, not an authenticated app user.
            school_id=None,
            method="CLI",
            path=f"cli/superadmin/{user.id}/password-reset",
            status_code=200,
            user_agent="server-terminal",
        ))
        db.commit()
    except BaseException:
        db.rollback()
        raise


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Восстановление пароля главного администратора в терминале сервера",
    )
    parser.add_argument("--login", required=True, help="Логин существующего главного администратора")
    args = parser.parse_args()
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        print("Нужен интерактивный терминал (SSH с TTY или docker exec -it).", file=sys.stderr)
        return 1

    try:
        print(f"Сброс пароля: {args.login.strip().lower()}")
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            password = getpass.getpass("Новый временный пароль (ввод скрыт): ")
            confirmation = getpass.getpass("Повторите пароль: ")
        if password != confirmation:
            raise RecoveryError("Пароли не совпадают. Изменений нет")
        validate_password(password)

        from app.config.database import SessionLocal
        with SessionLocal() as db:
            reset_password(db, args.login, password)
    except (EOFError, KeyboardInterrupt, getpass.GetPassWarning):
        print("Операция отменена: скрытый ввод не завершён.", file=sys.stderr)
        return 1
    except RecoveryError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception:
        # Avoid connection strings, hashes and secrets in terminal tracebacks.
        print("Сброс не выполнен. Проверьте конфигурацию backend и доступность БД.", file=sys.stderr)
        return 1

    print("Пароль изменён. При входе задайте постоянный пароль.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
