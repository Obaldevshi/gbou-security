from app.core.exceptions import NotFoundError
from app.models.exit_request import Student
from app.repositories.student_admin_repository import StudentAdminRepository
from app.schemas.student_admin import (
    StudentCreate,
    StudentImportResult,
    StudentImportRowError,
    StudentUpdate,
)


class StudentAdminService:
    def __init__(self, repository: StudentAdminRepository):
        self.repository = repository

    def list(self, school_id: int, class_id: int | None = None, building_id: int | None = None) -> list[Student]:
        if class_id is not None:
            self._class(school_id, class_id)
        return self.repository.list_for_school(school_id, class_id, building_id)

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
        if not active:
            self.repository.cancel_pending_requests(student.id)
        return self._save(student)

    def delete(self, school_id: int, student_id: int) -> None:
        student = self._student(school_id, student_id)
        try:
            self.repository.delete_with_requests(student)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def import_text(
        self,
        school_id: int,
        building_id: int,
        text: str,
        *,
        class_id: int | None = None,
        dry_run: bool = False,
    ) -> StudentImportResult:
        class_map = {
            item.name.strip().casefold(): item
            for item in self.repository.list_classes_for_school(school_id, building_id)
        }
        errors: list[StudentImportRowError] = []
        created_count = 0
        selected_class = self._class(school_id, class_id) if class_id is not None else None
        if selected_class is not None and selected_class.building_id != building_id:
            raise NotFoundError("Класс не относится к выбранному корпусу", code="school_class_not_found")
        try:
            for line_number, raw_line in enumerate(text.splitlines(), start=1):
                line = raw_line.strip()
                if not line:
                    continue
                parts = [part.strip() for part in line.split(";")]
                class_name = ""
                if selected_class is not None and len(parts) == 1:
                    names = [part for part in parts[0].split() if part]
                    if len(names) < 2:
                        errors.append(StudentImportRowError(line=line_number, message="ФИО должно содержать фамилию и имя"))
                        continue
                    last_name, first_name = names[:2]
                    middle_name = " ".join(names[2:]) or None
                    school_class = selected_class
                elif selected_class is not None and len(parts) == 3:
                    last_name, first_name, middle_name = parts
                    middle_name = middle_name or None
                    school_class = selected_class
                elif len(parts) == 2:
                    names = [part for part in parts[0].split() if part]
                    class_name = parts[1]
                    if len(names) < 2 or len(names) > 3:
                        errors.append(StudentImportRowError(line=line_number, message="ФИО должно содержать фамилию, имя и необязательное отчество"))
                        continue
                    last_name, first_name = names[:2]
                    middle_name = names[2] if len(names) == 3 else None
                    school_class = class_map.get(class_name.casefold())
                elif len(parts) == 4:
                    last_name, first_name, middle_name, class_name = parts
                    middle_name = middle_name or None
                    school_class = class_map.get(class_name.casefold())
                else:
                    errors.append(StudentImportRowError(
                        line=line_number,
                        message=("Используйте «ФИО» или «Фамилия;Имя;Отчество»" if selected_class is not None else "Используйте формат «ФИО;Класс» или «Фамилия;Имя;Отчество;Класс»"),
                    ))
                    continue
                if not last_name or not first_name:
                    message = "Укажите фамилию и имя"
                elif len(last_name) > 100 or len(first_name) > 100 or (middle_name and len(middle_name) > 100):
                    message = "Одна из частей ФИО слишком длинная"
                elif school_class is None:
                    message = f"Класс не найден: {class_name or 'не указан'}"
                else:
                    self.repository.add(Student(
                        school_id=school_id,
                        class_id=school_class.id,
                        last_name=last_name,
                        first_name=first_name,
                        middle_name=middle_name,
                        is_active=True,
                    ))
                    created_count += 1
                    continue
                errors.append(StudentImportRowError(line=line_number, message=message))
            if dry_run:
                self.repository.rollback()
            elif created_count:
                self.repository.commit()
            return StudentImportResult(created_count=created_count, errors=errors)
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
