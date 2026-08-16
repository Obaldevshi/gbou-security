from types import SimpleNamespace

import pytest

from app.core.exceptions import UnauthorizedError, UnprocessableEntityError
from app.core.security import get_password_hash, verify_password
from app.services.user_service import UserService


class FakeUserRepository:
    def __init__(self):
        self.commits = 0
        self.rollbacks = 0

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


def test_user_changes_password():
    repository = FakeUserRepository()
    user = SimpleNamespace(hashed_password=get_password_hash("OldPassword123!"))

    UserService(repository).change_password(user, "OldPassword123!", "NewPassword123!")

    assert verify_password("NewPassword123!", user.hashed_password)
    assert repository.commits == 1


def test_current_password_must_be_valid():
    repository = FakeUserRepository()
    user = SimpleNamespace(hashed_password=get_password_hash("OldPassword123!"))

    with pytest.raises(UnauthorizedError) as error:
        UserService(repository).change_password(user, "wrong", "NewPassword123!")

    assert error.value.code == "invalid_current_password"
    assert repository.commits == 0


def test_new_password_must_be_different():
    repository = FakeUserRepository()
    user = SimpleNamespace(hashed_password=get_password_hash("SamePassword123!"))

    with pytest.raises(UnprocessableEntityError) as error:
        UserService(repository).change_password(
            user,
            "SamePassword123!",
            "SamePassword123!",
        )

    assert error.value.code == "password_unchanged"
