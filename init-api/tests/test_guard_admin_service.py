import unittest
from types import SimpleNamespace

from app.core.exceptions import ConflictError, NotFoundError
from app.models.user import UserRole
from app.schemas.guard_admin import GuardCreate
from app.services.guard_admin_service import GuardAdminService


class FakeGuardRepository:
    def __init__(self):
        self.items = {}
        self.logins = set()
        self.deleted = []
        self.commits = 0
        self.rollbacks = 0

    def list_for_school(self, school_id):
        return [item for item in self.items.values() if item.school_id == school_id]

    def get_for_school(self, guard_id, school_id):
        item = self.items.get(guard_id)
        return item if item and item.school_id == school_id and item.role == UserRole.GUARD else None

    def login_exists(self, login, exclude_id=None):
        return login in self.logins

    def add(self, guard):
        guard.id = 1
        self.items[1] = guard
        self.logins.add(guard.login)

    def delete_preserving_history(self, guard):
        self.deleted.append(guard.id)
        self.items.pop(guard.id)

    def commit(self): self.commits += 1
    def rollback(self): self.rollbacks += 1
    def refresh(self, guard): return guard


class GuardAdminServiceTest(unittest.TestCase):
    def payload(self):
        return GuardCreate(login="guard.two", full_name="Пост охраны №2", phone=None, password="StrongPass123!")

    def test_create_uses_current_school_and_guard_role(self):
        repository = FakeGuardRepository()
        guard = GuardAdminService(repository).create(1, self.payload())
        self.assertEqual(guard.school_id, 1)
        self.assertEqual(guard.role, UserRole.GUARD)
        self.assertEqual(repository.commits, 1)

    def test_duplicate_login_is_rejected(self):
        repository = FakeGuardRepository()
        repository.logins.add("guard.two")
        with self.assertRaises(ConflictError):
            GuardAdminService(repository).create(1, self.payload())

    def test_foreign_guard_is_hidden(self):
        repository = FakeGuardRepository()
        repository.items[1] = SimpleNamespace(id=1, school_id=1, role=UserRole.GUARD)
        with self.assertRaises(NotFoundError):
            GuardAdminService(repository).delete(2, 1)
        self.assertEqual(repository.deleted, [])


if __name__ == "__main__":
    unittest.main()
