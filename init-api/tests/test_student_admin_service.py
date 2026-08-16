import unittest
from types import SimpleNamespace

from app.core.exceptions import NotFoundError
from app.schemas.student_admin import StudentCreate
from app.services.student_admin_service import StudentAdminService


class FakeStudentRepository:
    def __init__(self):
        self.classes = {(1, 10): SimpleNamespace(id=10, school_id=1, name="5А")}
        self.students = {}
        self.deleted = []
        self.commits = 0
        self.rollbacks = 0

    def get_class_for_school(self, class_id, school_id):
        return self.classes.get((school_id, class_id))

    def get_for_school(self, student_id, school_id):
        student = self.students.get(student_id)
        return student if student and student.school_id == school_id else None

    def list_for_school(self, school_id, class_id=None):
        return [item for item in self.students.values() if item.school_id == school_id and (class_id is None or item.class_id == class_id)]

    def add(self, student):
        student.id = 1
        self.students[student.id] = student

    def delete_with_requests(self, student):
        self.deleted.append(student.id)
        self.students.pop(student.id)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def refresh(self, student):
        return student


class StudentAdminServiceTest(unittest.TestCase):
    def test_create_student_uses_current_school(self):
        repository = FakeStudentRepository()
        service = StudentAdminService(repository)
        student = service.create(1, StudentCreate(class_id=10, last_name="Иванов", first_name="Иван", middle_name=None))
        self.assertEqual(student.school_id, 1)
        self.assertEqual(student.class_id, 10)
        self.assertEqual(repository.commits, 1)

    def test_foreign_class_is_hidden(self):
        repository = FakeStudentRepository()
        service = StudentAdminService(repository)
        with self.assertRaises(NotFoundError) as error:
            service.create(2, StudentCreate(class_id=10, last_name="Иванов", first_name="Иван"))
        self.assertEqual(error.exception.code, "school_class_not_found")

    def test_delete_foreign_student_is_hidden(self):
        repository = FakeStudentRepository()
        repository.students[1] = SimpleNamespace(id=1, school_id=1, class_id=10)
        service = StudentAdminService(repository)
        with self.assertRaises(NotFoundError) as error:
            service.delete(2, 1)
        self.assertEqual(error.exception.code, "student_not_found")
        self.assertEqual(repository.deleted, [])


if __name__ == "__main__":
    unittest.main()
