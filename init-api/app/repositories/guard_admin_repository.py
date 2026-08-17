from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import ExitRequest
from app.models.user import User, UserRole


class GuardAdminRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int, building_id: int | None = None) -> list[User]:
        query = self.db.query(User).options(joinedload(User.building)).filter(User.school_id == school_id, User.role == UserRole.GUARD)
        if building_id is not None:
            query = query.filter(User.building_id == building_id)
        return query.order_by(User.full_name.asc()).all()

    def get_for_school(self, guard_id: int, school_id: int) -> User | None:
        return self.db.query(User).options(joinedload(User.building)).filter(User.id == guard_id, User.school_id == school_id, User.role == UserRole.GUARD).first()

    def building_exists(self, school_id: int, building_id: int) -> bool:
        from app.models.school_building import SchoolBuilding
        return self.db.query(SchoolBuilding.id).filter(SchoolBuilding.id == building_id, SchoolBuilding.school_id == school_id).first() is not None

    def login_exists(self, login: str, exclude_id: int | None = None) -> bool:
        query = self.db.query(User.id).filter(User.login == login.strip().lower())
        if exclude_id is not None:
            query = query.filter(User.id != exclude_id)
        return query.first() is not None

    def add(self, guard: User) -> None:
        self.db.add(guard)

    def delete_preserving_history(self, guard: User) -> None:
        self.db.query(ExitRequest).filter(ExitRequest.released_by_id == guard.id).update({ExitRequest.released_by_id: None}, synchronize_session=False)
        self.db.delete(guard)

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, guard: User) -> User:
        self.db.refresh(guard)
        return guard
