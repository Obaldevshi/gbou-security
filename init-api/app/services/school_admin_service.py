from app.core.exceptions import ConflictError, NotFoundError, ValidationError
from app.core.security import get_password_hash
from app.models.user import User, UserRole
from app.repositories.school_repository import SchoolRepository
from app.repositories.user_repository import UserRepository
from app.schemas.school_admin import SchoolAdminCreate, SchoolAdminUpdate


class SchoolAdminService:
    def __init__(
        self,
        users: UserRepository,
        schools: SchoolRepository,
    ):
        self.users = users
        self.schools = schools

    def list(self) -> list[User]:
        return self.users.list_by_role(UserRole.SCHOOL_ADMIN)

    def create(self, payload: SchoolAdminCreate) -> User:
        self._require_school(payload.school_id)
        self._require_unique_login(payload.login)
        user = User(
            school_id=payload.school_id,
            login=payload.login,
            full_name=payload.full_name,
            phone=payload.phone,
            hashed_password=get_password_hash(payload.password),
            role=UserRole.SCHOOL_ADMIN,
            is_active=True,
            must_change_password=True,
        )
        try:
            self.users.db.add(user)
            self.users.commit()
            return self.users.refresh(user)
        except Exception:
            self.users.rollback()
            raise

    def update(self, user_id: int, payload: SchoolAdminUpdate) -> User:
        user = self._get(user_id)
        changes = payload.model_dump(exclude_none=True)
        if not changes:
            raise ValidationError("Укажите хотя бы одно изменение", code="user_no_changes")
        if "school_id" in changes:
            self._require_school(changes["school_id"])
        if "login" in changes:
            self._require_unique_login(changes["login"], user.id)
        password = changes.pop("password", None)
        if password is not None:
            changes["hashed_password"] = get_password_hash(password)
            changes["must_change_password"] = True
        for field, value in changes.items():
            setattr(user, field, value)
        return self._save(user)

    def set_status(self, user_id: int, is_active: bool) -> User:
        user = self._get(user_id)
        user.is_active = is_active
        return self._save(user)

    def delete(self, user_id: int) -> None:
        user = self._get(user_id)
        try:
            self.users.db.delete(user)
            self.users.commit()
        except Exception:
            self.users.rollback()
            raise

    def _get(self, user_id: int) -> User:
        user = self.users.get_by_id(user_id)
        if user is None or user.role != UserRole.SCHOOL_ADMIN:
            raise NotFoundError("Администратор школы не найден", code="school_admin_not_found")
        return user

    def _require_school(self, school_id: int) -> None:
        if self.schools.get_by_id(school_id) is None:
            raise NotFoundError("Школа не найдена", code="school_not_found")

    def _require_unique_login(self, login: str, exclude_id: int | None = None) -> None:
        if self.users.login_exists(login, exclude_id):
            raise ConflictError("Этот логин уже занят", code="login_already_exists")

    def _save(self, user: User) -> User:
        try:
            self.users.commit()
            return self.users.refresh(user)
        except Exception:
            self.users.rollback()
            raise
