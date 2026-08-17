from __future__ import annotations

from app.core.exceptions import ConflictError, NotFoundError
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.repositories.teacher_admin_repository import TeacherAdminRepository
from app.schemas.teacher_admin import (
    TeacherCreate,
    TeacherImportResult,
    TeacherImportRowError,
    TeacherUpdate,
)


class TeacherAdminService:
    def __init__(self, repository: TeacherAdminRepository):
        self.repository = repository

    def list(self, school_id: int, building_id: int | None = None) -> list[User]:
        return self.repository.list_for_school(school_id, building_id)

    def create(self, school_id: int, payload: TeacherCreate) -> User:
        self._building(school_id, payload.building_id)
        classes = self._classes(school_id, payload.building_id, payload.class_ids)
        self._unique_login(payload.login)
        teacher = User(
            school_id=school_id,
            building_id=payload.building_id,
            login=payload.login,
            full_name=payload.full_name,
            phone=payload.phone,
            hashed_password=get_password_hash(payload.password),
            role=UserRole.TEACHER,
            is_active=True,
            must_change_password=True,
        )
        self.repository.add(teacher)
        self.repository.replace_assignments(teacher, classes)
        return self._save(teacher)

    def update(self, school_id: int, teacher_id: int, payload: TeacherUpdate) -> User:
        teacher = self._teacher(school_id, teacher_id)
        self._building(school_id, payload.building_id)
        classes = self._classes(school_id, payload.building_id, payload.class_ids)
        self._unique_login(payload.login, teacher.id)
        teacher.login = payload.login
        teacher.full_name = payload.full_name
        teacher.phone = payload.phone
        teacher.building_id = payload.building_id
        if payload.password is not None:
            teacher.hashed_password = get_password_hash(payload.password)
            teacher.must_change_password = True
        self.repository.replace_assignments(teacher, classes)
        return self._save(teacher)

    def set_status(self, school_id: int, teacher_id: int, active: bool) -> User:
        teacher = self._teacher(school_id, teacher_id)
        teacher.is_active = active
        if not active:
            self.repository.cancel_pending_requests(teacher.id)
        return self._save(teacher)

    def delete(self, school_id: int, teacher_id: int) -> None:
        teacher = self._teacher(school_id, teacher_id)
        try:
            self.repository.delete_with_requests(teacher)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def import_text(self, school_id: int, building_id: int, text: str, *, dry_run: bool = False) -> TeacherImportResult:
        self._building(school_id, building_id)
        class_map = {
            item.name.strip().casefold(): item
            for item in self.repository.list_classes_for_school(school_id, building_id)
        }
        errors: list[TeacherImportRowError] = []
        seen_logins: set[str] = set()
        created_count = 0

        try:
            for line_number, raw_line in enumerate(text.splitlines(), start=1):
                line = raw_line.strip()
                if not line:
                    continue
                parts = [part.strip() for part in line.split(";")]
                if len(parts) != 5:
                    errors.append(TeacherImportRowError(line=line_number, message="Ожидается 5 полей, разделённых точкой с запятой"))
                    continue
                full_name, login, phone, password, raw_classes = parts
                login = login.lower()
                class_names = [item.strip() for item in raw_classes.split(",") if item.strip()]
                missing = [name for name in class_names if name.casefold() not in class_map]
                if not full_name or len(full_name) < 3:
                    message = "Укажите полное ФИО"
                elif len(login) < 3:
                    message = "Логин должен содержать не менее 3 символов"
                elif len(phone) > 32:
                    message = "Телефон слишком длинный"
                elif len(password) < 12 or len(password) > 128:
                    message = "Пароль должен содержать от 12 до 128 символов"
                elif not class_names:
                    message = "Укажите хотя бы один класс"
                elif missing:
                    message = f"Классы не найдены: {', '.join(missing)}"
                elif login in seen_logins or self.repository.login_exists(login):
                    message = "Этот логин уже занят"
                else:
                    teacher = User(
                        school_id=school_id,
                        building_id=building_id,
                        login=login,
                        full_name=" ".join(full_name.split()),
                        phone=" ".join(phone.split()) if phone else None,
                        hashed_password=get_password_hash(password),
                        role=UserRole.TEACHER,
                        is_active=True,
                        must_change_password=True,
                    )
                    classes = [class_map[name.casefold()] for name in class_names]
                    self.repository.add(teacher)
                    self.repository.replace_assignments(teacher, classes)
                    seen_logins.add(login)
                    created_count += 1
                    continue
                errors.append(TeacherImportRowError(line=line_number, message=message))

            if dry_run:
                self.repository.rollback()
            elif created_count:
                self.repository.commit()
            return TeacherImportResult(created_count=created_count, errors=errors)
        except Exception:
            self.repository.rollback()
            raise

    def _teacher(self, school_id: int, teacher_id: int) -> User:
        teacher = self.repository.get_for_school(teacher_id, school_id)
        if teacher is None:
            raise NotFoundError("Учитель не найден", code="teacher_not_found")
        return teacher

    def _building(self, school_id: int, building_id: int) -> None:
        if not self.repository.building_exists(school_id, building_id):
            raise NotFoundError("Корпус не найден", code="school_building_not_found")

    def _classes(self, school_id: int, building_id: int, class_ids: list[int]):
        classes = self.repository.get_classes_for_school(class_ids, school_id, building_id)
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
