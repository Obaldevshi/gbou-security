from __future__ import annotations

from app.core.exceptions import ConflictError, NotFoundError
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.repositories.teacher_admin_repository import TeacherAdminRepository
from app.schemas.teacher_admin import TeacherCreate, TeacherUpdate


class TeacherAdminService:
    def __init__(self, repository: TeacherAdminRepository):
        self.repository = repository

    def list(self, school_id: int) -> list[User]:
        return self.repository.list_for_school(school_id)

    def create(self, school_id: int, payload: TeacherCreate) -> User:
        classes = self._classes(school_id, payload.class_ids)
        self._unique_login(payload.login)
        teacher = User(
            school_id=school_id,
            login=payload.login,
            full_name=payload.full_name,
            phone=payload.phone,
            hashed_password=get_password_hash(payload.password),
            role=UserRole.TEACHER,
            is_active=True,
        )
        self.repository.add(teacher)
        self.repository.replace_assignments(teacher, classes)
        return self._save(teacher)

    def update(self, school_id: int, teacher_id: int, payload: TeacherUpdate) -> User:
        teacher = self._teacher(school_id, teacher_id)
        classes = self._classes(school_id, payload.class_ids)
        self._unique_login(payload.login, teacher.id)
        teacher.login = payload.login
        teacher.full_name = payload.full_name
        teacher.phone = payload.phone
        if payload.password is not None:
            teacher.hashed_password = get_password_hash(payload.password)
        self.repository.replace_assignments(teacher, classes)
        return self._save(teacher)

    def set_status(self, school_id: int, teacher_id: int, active: bool) -> User:
        teacher = self._teacher(school_id, teacher_id)
        teacher.is_active = active
        return self._save(teacher)

    def delete(self, school_id: int, teacher_id: int) -> None:
        teacher = self._teacher(school_id, teacher_id)
        try:
            self.repository.delete_with_requests(teacher)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _teacher(self, school_id: int, teacher_id: int) -> User:
        teacher = self.repository.get_for_school(teacher_id, school_id)
        if teacher is None:
            raise NotFoundError("Учитель не найден", code="teacher_not_found")
        return teacher

    def _classes(self, school_id: int, class_ids: list[int]):
        classes = self.repository.get_classes_for_school(class_ids, school_id)
        if len(classes) != len(class_ids):
            raise NotFoundError("Один или несколько классов не найдены", code="school_class_not_found")
        by_id = {item.id: item for item in classes}
        return [by_id[item] for item in class_ids]

    def _unique_login(self, login: str, exclude_id: int | None = None) -> None:
        if self.repository.login_exists(login, exclude_id):
            raise ConflictError("Этот логин уже занят", code="login_already_exists")

    def _save(self, teacher: User) -> User:
        try:
            self.repository.commit()
            return self.repository.refresh(teacher)
        except Exception:
            self.repository.rollback()
            raise
