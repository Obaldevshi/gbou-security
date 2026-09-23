from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.models import UserRole
from scripts.reset_superadmin_password import main, reset_password, validate_password


def make_db(role=UserRole.SUPER_ADMIN, active=True):
    user = SimpleNamespace(
        id=7, role=role, is_active=active, hashed_password="old-hash",
        password_reset_marker="old-marker",
        must_change_password=False,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.with_for_update.return_value.one_or_none.return_value = user
    return db, user


def test_reset_targets_existing_superadmin(monkeypatch):
    db, user = make_db()
    monkeypatch.setattr("app.core.security.get_password_hash", lambda _: "new-hash")
    reset_password(db, " SUPERADMIN ", "Temporary123")
    assert user.hashed_password == "new-hash"
    assert user.must_change_password is True
    assert user.password_reset_marker != "old-marker"
    event = db.add.call_args.args[0]
    assert event.method == "CLI"
    assert event.actor_id is None
    assert event.path == "cli/superadmin/7/password-reset"
    db.query.return_value.filter.return_value.update.assert_called_once()
    db.commit.assert_called_once()


@pytest.mark.parametrize("role", [UserRole.TEACHER, UserRole.GUARD, UserRole.SCHOOL_ADMIN])
def test_reset_refuses_other_roles(role):
    db, user = make_db(role=role)
    with pytest.raises(ValueError):
        reset_password(db, "someone", "Temporary123")
    assert user.hashed_password == "old-hash"
    db.commit.assert_not_called()
    db.rollback.assert_called_once()


def test_reset_refuses_unknown_login():
    db, _ = make_db()
    db.query.return_value.filter.return_value.with_for_update.return_value.one_or_none.return_value = None
    with pytest.raises(ValueError):
        reset_password(db, "missing", "Temporary123")
    db.commit.assert_not_called()


def test_reset_does_not_reactivate_disabled_account():
    db, user = make_db(active=False)
    with pytest.raises(ValueError):
        reset_password(db, "superadmin", "Temporary123")
    assert user.is_active is False
    assert user.hashed_password == "old-hash"
    db.commit.assert_not_called()


@pytest.mark.parametrize("password", ["shortA", "12345678", "я" * 37])
def test_invalid_password_is_rejected_before_query(password):
    db, _ = make_db()
    with pytest.raises(ValueError):
        reset_password(db, "superadmin", password)
    db.query.assert_not_called()
    db.commit.assert_not_called()


def test_password_policy_accepts_letters_without_other_complexity():
    validate_password("abcdefgh")
    validate_password("Пароль123")


def test_reset_rolls_back_failed_commit(monkeypatch):
    db, _ = make_db()
    monkeypatch.setattr("app.core.security.get_password_hash", lambda _: "new-hash")
    db.commit.side_effect = RuntimeError("database unavailable")
    with pytest.raises(RuntimeError):
        reset_password(db, "superadmin", "Temporary123")
    db.rollback.assert_called_once()


def test_cli_refuses_noninteractive_password_input(monkeypatch):
    monkeypatch.setattr("sys.argv", ["reset_superadmin_password", "--login", "superadmin"])
    monkeypatch.setattr("sys.stdin.isatty", lambda: False)
    prompt = MagicMock()
    monkeypatch.setattr("getpass.getpass", prompt)
    assert main() == 1
    prompt.assert_not_called()


def test_cli_mismatched_passwords_never_reset(monkeypatch, capsys):
    monkeypatch.setattr("sys.argv", ["reset_superadmin_password", "--login", "superadmin"])
    monkeypatch.setattr("sys.stdin.isatty", lambda: True)
    monkeypatch.setattr("sys.stderr.isatty", lambda: True)
    monkeypatch.setattr("getpass.getpass", MagicMock(side_effect=["Temporary123", "Different123"]))
    reset = MagicMock()
    monkeypatch.setattr("scripts.reset_superadmin_password.reset_password", reset)
    assert main() == 1
    reset.assert_not_called()
    captured = capsys.readouterr()
    assert "Temporary123" not in captured.out + captured.err


def test_no_http_recovery_routes():
    from app.api.v1.auth import router

    paths = {route.path for route in router.routes}
    assert "/superadmin/recover" not in paths
    assert "/superadmin/recovery-codes" not in paths
    assert "/login" in paths
