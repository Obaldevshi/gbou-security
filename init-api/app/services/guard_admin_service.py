from app.core.exceptions import ConflictError, NotFoundError
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.repositories.guard_admin_repository import GuardAdminRepository
from app.schemas.guard_admin import GuardCreate, GuardUpdate


class GuardAdminService:
    def __init__(self, repository: GuardAdminRepository):
        self.repository = repository

    def list(self, school_id: int, building_id: int | None = None) -> list[User]:
        return self.repository.list_for_school(school_id, building_id)

    def create(self, school_id: int, payload: GuardCreate) -> User:
        self._building(school_id, payload.building_id)
        self._unique(payload.login)
        guard = User(school_id=school_id, building_id=payload.building_id, login=payload.login, full_name=payload.full_name, phone=payload.phone, hashed_password=get_password_hash(payload.password), role=UserRole.GUARD, is_active=True, must_change_password=True)
        self.repository.add(guard)
        return self._save(guard)

    def update(self, school_id: int, guard_id: int, payload: GuardUpdate) -> User:
        guard = self._get(school_id, guard_id)
        self._building(school_id, payload.building_id)
        self._unique(payload.login, guard.id)
        guard.login = payload.login
        guard.full_name = payload.full_name
        guard.phone = payload.phone
        guard.building_id = payload.building_id
        if payload.password is not None:
            guard.hashed_password = get_password_hash(payload.password)
            guard.must_change_password = True
        return self._save(guard)

    def set_status(self, school_id: int, guard_id: int, active: bool) -> User:
        guard = self._get(school_id, guard_id)
        guard.is_active = active
        return self._save(guard)

    def delete(self, school_id: int, guard_id: int) -> None:
        guard = self._get(school_id, guard_id)
        try:
            self.repository.delete_preserving_history(guard)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _get(self, school_id: int, guard_id: int) -> User:
        guard = self.repository.get_for_school(guard_id, school_id)
        if guard is None:
            raise NotFoundError("Пользователь охраны не найден", code="guard_not_found")
        return guard

    def _unique(self, login: str, exclude_id: int | None = None) -> None:
        if self.repository.login_exists(login, exclude_id):
            raise ConflictError("Этот логин уже занят", code="login_already_exists")

    def _building(self, school_id: int, building_id: int) -> None:
        if not self.repository.building_exists(school_id, building_id):
            raise NotFoundError("Корпус не найден", code="school_building_not_found")

    def _save(self, guard: User) -> User:
        try:
            self.repository.commit()
            return self.repository.refresh(guard)
        except Exception:
            self.repository.rollback()
            raise
