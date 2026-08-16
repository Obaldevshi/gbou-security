import unittest
from types import SimpleNamespace

from app.core.exceptions import ConflictError, NotFoundError
from app.models.user import UserRole
from app.schemas.teacher_admin import TeacherCreate
from app.services.teacher_admin_service import TeacherAdminService


class FakeTeacherRepository:
    def __init__(self):
        self.classes = {
            (1, 10): SimpleNamespace(id=10, school_id=1, name="5А"),
            (1, 11): SimpleNamespace(id=11, school_id=1, name="7Б"),
        }
        self.teachers = {}
        self.logins = set()
        self.commits = 0
        self.rollbacks = 0

    def list_for_school(self, school_id):
        return [item for item in self.teachers.values() if item.school_id == school_id]

    def get_for_school(self, teacher_id, school_id):
        item = self.teachers.get(teacher_id)
        return item if item and item.school_id == school_id else None

    def get_classes_for_school(self, class_ids, school_id):
        return [self.classes[(school_id, item)] for item in class_ids if (school_id, item) in self.classes]

    def login_exists(self, login, exclude_id=None):
        return login in self.logins

    def add(self, teacher):
        teacher.id = 1
        teacher.class_assignments = []
        self.teachers[teacher.id] = teacher
        self.logins.add(teacher.login)

    def replace_assignments(self, teacher, classes):
        teacher.assigned_class_ids = [item.id for item in classes]

    def delete_with_requests(self, teacher):
        self.teachers.pop(teacher.id)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def refresh(self, teacher):
        return teacher


class TeacherAdminServiceTest(unittest.TestCase):
    def payload(self, **changes):
        values = dict(login="teacher.one", full_name="Иванова Мария", phone=None, password="StrongPass123!", class_ids=[10, 11])
        values.update(changes)
        return TeacherCreate(**values)

    def test_create_uses_current_school_role_and_classes(self):
        repository = FakeTeacherRepository()
        teacher = TeacherAdminService(repository).create(1, self.payload())
        self.assertEqual(teacher.school_id, 1)
        self.assertEqual(teacher.role, UserRole.TEACHER)
        self.assertEqual(teacher.assigned_class_ids, [10, 11])
        self.assertEqual(repository.commits, 1)

    def test_foreign_class_is_hidden(self):
        with self.assertRaises(NotFoundError) as error:
            TeacherAdminService(FakeTeacherRepository()).create(2, self.payload(class_ids=[10]))
        self.assertEqual(error.exception.code, "school_class_not_found")

    def test_duplicate_login_is_rejected(self):
        repository = FakeTeacherRepository()
        repository.logins.add("teacher.one")
        with self.assertRaises(ConflictError) as error:
            TeacherAdminService(repository).create(1, self.payload())
        self.assertEqual(error.exception.code, "login_already_exists")


if __name__ == "__main__":
    unittest.main()
