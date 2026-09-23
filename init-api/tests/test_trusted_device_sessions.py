from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.core.exceptions import UnauthorizedError
from app.models.user import UserRole
from app.services.auth_service import AuthService


class FakeUsers:
    def __init__(self, user):
        self.user = user

    def get_by_id(self, user_id):
        return self.user if self.user.id == user_id else None


class FakeTrustedDevices:
    def __init__(self):
        self.items = []
        self.commits = 0
        self.rollbacks = 0

    def create(self, session):
        session.id = len(self.items) + 1
        session.created_at = datetime.now(timezone.utc)
        session.updated_at = session.created_at
        self.items.append(session)
        return session

    def get_by_token_hash_for_update(self, token_hash):
        return next((item for item in self.items if item.token_hash == token_hash), None)

    def list_active_for_user(self, user_id):
        now = datetime.now(timezone.utc)
        return [
            item
            for item in reversed(self.items)
            if item.user_id == user_id
            and item.revoked_at is None
            and item.expires_at > now
        ]

    def get_active_for_user(self, user_id, session_id):
        return next(
            (
                item
                for item in self.items
                if item.user_id == user_id
                and item.id == session_id
                and item.revoked_at is None
            ),
            None,
        )

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def refresh(self, session):
        return session


def make_user():
    now = datetime.now(timezone.utc)
    return SimpleNamespace(
        id=17,
        login="superadmin",
        full_name="Главный администратор",
        phone=None,
        role=UserRole.SUPER_ADMIN,
        school_id=None,
        school=None,
        is_active=True,
        must_change_password=False,
        created_at=now,
        updated_at=now,
    )


def test_trusted_token_is_hashed_and_rotated():
    user = make_user()
    devices = FakeTrustedDevices()
    service = AuthService(FakeUsers(user), devices)

    created = service.create_trusted_device(user, "Android-телефон")
    stored = devices.items[0]
    assert created.refresh_token not in stored.token_hash
    assert len(stored.token_hash) == 64

    refreshed = service.refresh_trusted_device(created.refresh_token)
    assert refreshed.refresh_token != created.refresh_token
    assert refreshed.trusted_device_id == created.id

    with pytest.raises(UnauthorizedError) as error:
        service.refresh_trusted_device(created.refresh_token)
    assert error.value.code == "trusted_session_invalid"


def test_expired_or_revoked_device_cannot_refresh():
    user = make_user()
    devices = FakeTrustedDevices()
    service = AuthService(FakeUsers(user), devices)
    created = service.create_trusted_device(user, "Планшет охраны")

    devices.items[0].expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    with pytest.raises(UnauthorizedError) as error:
        service.refresh_trusted_device(created.refresh_token)
    assert error.value.code == "trusted_session_expired"
    assert devices.items[0].revoked_at is not None


def test_revocation_is_scoped_to_current_user():
    user = make_user()
    devices = FakeTrustedDevices()
    service = AuthService(FakeUsers(user), devices)
    created = service.create_trusted_device(user, "Рабочий телефон")

    other_user = make_user()
    other_user.id = 18
    with pytest.raises(Exception):
        service.revoke_trusted_device(other_user, created.id)
    assert devices.items[0].revoked_at is None

    service.revoke_trusted_device(user, created.id)
    assert devices.items[0].revoked_at is not None
