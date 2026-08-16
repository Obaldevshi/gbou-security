from app.constants.messages import SchoolMessages
from app.core.exceptions import ConflictError, NotFoundError, ValidationError
from app.models.school import School
from app.repositories.school_repository import SchoolRepository
from app.schemas.school import SchoolCreate, SchoolStatusUpdate, SchoolUpdate


class SchoolService:
    def __init__(self, repository: SchoolRepository):
        self.repository = repository

    def list_schools(self) -> list[School]:
        return self.repository.list_all()

    def get_system_stats(self) -> dict[str, int]:
        return self.repository.get_system_stats()

    def create_school(self, payload: SchoolCreate) -> School:
        self._ensure_unique(payload.full_name, payload.short_name)
        school = School(**payload.model_dump(), is_active=True)
        try:
            self.repository.add(school)
            self.repository.commit()
            return self.repository.refresh(school)
        except Exception:
            self.repository.rollback()
            raise

    def update_school(self, school_id: int, payload: SchoolUpdate) -> School:
        school = self._get_school(school_id)
        changes = payload.model_dump(exclude_none=True)
        if not changes:
            raise ValidationError(
                SchoolMessages.NO_CHANGES.value,
                code="school_no_changes",
            )
        full_name = changes.get("full_name", school.full_name)
        short_name = changes.get("short_name", school.short_name)
        self._ensure_unique(full_name, short_name, exclude_school_id=school.id)
        for field, value in changes.items():
            setattr(school, field, value)
        return self._save(school)

    def set_school_status(
        self,
        school_id: int,
        payload: SchoolStatusUpdate,
    ) -> School:
        school = self._get_school(school_id)
        school.is_active = payload.is_active
        return self._save(school)

    def delete_school(self, school_id: int) -> None:
        school = self._get_school(school_id)
        try:
            self.repository.delete_with_dependencies(school)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _get_school(self, school_id: int) -> School:
        school = self.repository.get_by_id(school_id)
        if school is None:
            raise NotFoundError(
                SchoolMessages.NOT_FOUND.value,
                code="school_not_found",
            )
        return school

    def _ensure_unique(
        self,
        full_name: str,
        short_name: str,
        *,
        exclude_school_id: int | None = None,
    ) -> None:
        if self.repository.has_name_conflict(
            full_name=full_name,
            short_name=short_name,
            exclude_school_id=exclude_school_id,
        ):
            raise ConflictError(
                SchoolMessages.ALREADY_EXISTS.value,
                code="school_already_exists",
            )

    def _save(self, school: School) -> School:
        try:
            self.repository.commit()
            return self.repository.refresh(school)
        except Exception:
            self.repository.rollback()
            raise
