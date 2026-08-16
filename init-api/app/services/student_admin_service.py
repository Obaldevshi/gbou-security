from app.core.exceptions import NotFoundError
from app.models.exit_request import Student
from app.repositories.student_admin_repository import StudentAdminRepository
from app.schemas.student_admin import StudentCreate, StudentUpdate


class StudentAdminService:
    def __init__(self, repository: StudentAdminRepository):
        self.repository = repository

    def list(self, school_id: int, class_id: int | None = None) -> list[Student]:
        if class_id is not None:
            self._class(school_id, class_id)
        return self.repository.list_for_school(school_id, class_id)

    def create(self, school_id: int, payload: StudentCreate) -> Student:
        self._class(school_id, payload.class_id)
        student = Student(school_id=school_id, is_active=True, **payload.model_dump())
        self.repository.add(student)
        return self._save(student)

    def update(self, school_id: int, student_id: int, payload: StudentUpdate) -> Student:
        student = self._student(school_id, student_id)
        self._class(school_id, payload.class_id)
        for field, value in payload.model_dump().items():
            setattr(student, field, value)
        return self._save(student)

    def set_status(self, school_id: int, student_id: int, active: bool) -> Student:
        student = self._student(school_id, student_id)
        student.is_active = active
        return self._save(student)

    def delete(self, school_id: int, student_id: int) -> None:
        student = self._student(school_id, student_id)
        try:
            self.repository.delete_with_requests(student)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _student(self, school_id: int, student_id: int) -> Student:
        student = self.repository.get_for_school(student_id, school_id)
        if student is None:
            raise NotFoundError("Ученик не найден", code="student_not_found")
        return student

    def _class(self, school_id: int, class_id: int):
        school_class = self.repository.get_class_for_school(class_id, school_id)
        if school_class is None:
            raise NotFoundError("Класс не найден", code="school_class_not_found")
        return school_class

    def _save(self, student: Student) -> Student:
        try:
            self.repository.commit()
            return self.repository.refresh(student)
        except Exception:
            self.repository.rollback()
            raise
