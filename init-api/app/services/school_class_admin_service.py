from app.core.exceptions import ConflictError, NotFoundError
from app.models.exit_request import SchoolClass
from app.repositories.school_class_admin_repository import SchoolClassAdminRepository


class SchoolClassAdminService:
    def __init__(self, repository: SchoolClassAdminRepository):
        self.repository = repository

    def list(self, school_id: int) -> list[SchoolClass]:
        return self.repository.list_for_school(school_id)

    def create(self, school_id: int, name: str) -> SchoolClass:
        self._unique(school_id, name)
        school_class = SchoolClass(school_id=school_id, name=name, is_active=True)
        self.repository.add(school_class)
        return self._save(school_class)

    def update(self, school_id: int, class_id: int, name: str) -> SchoolClass:
        school_class = self._get(school_id, class_id)
        self._unique(school_id, name, class_id)
        school_class.name = name
        return self._save(school_class)

    def set_status(self, school_id: int, class_id: int, active: bool) -> SchoolClass:
        school_class = self._get(school_id, class_id)
        school_class.is_active = active
        if not active:
            self.repository.cancel_pending_requests(school_class.id)
        return self._save(school_class)

    def delete(self, school_id: int, class_id: int) -> None:
        school_class = self._get(school_id, class_id)
        try:
            self.repository.delete_with_dependencies(school_class)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _get(self, school_id: int, class_id: int) -> SchoolClass:
        school_class = self.repository.get_for_school(class_id, school_id)
        if school_class is None:
            raise NotFoundError("Класс не найден", code="school_class_not_found")
        return school_class

    def _unique(self, school_id: int, name: str, exclude_id: int | None = None) -> None:
        if self.repository.name_exists(school_id, name, exclude_id):
            raise ConflictError("Класс с таким названием уже существует", code="school_class_exists")

    def _save(self, school_class: SchoolClass) -> SchoolClass:
        try:
            self.repository.commit()
            return self.repository.refresh(school_class)
        except Exception:
            self.repository.rollback()
            raise
