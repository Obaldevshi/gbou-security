from sqlalchemy.orm import Session
from typing import Optional

from app.models.user import User, UserRole
from .base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, db: Session):
        super().__init__(db, User)

    def get_by_login(self, login: str) -> Optional[User]:
        return self.db.query(User).filter(User.login == login.strip().lower()).first()

    def login_exists(self, login: str, exclude_user_id: Optional[int] = None) -> bool:
        query = self.db.query(User.id).filter(User.login == login.strip().lower())
        if exclude_user_id:
            query = query.filter(User.id != exclude_user_id)
        return query.first() is not None

    def list_by_role(self, role: UserRole) -> list[User]:
        return (
            self.db.query(User)
            .filter(User.role == role)
            .order_by(User.full_name.asc())
            .all()
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, user: User) -> User:
        self.db.refresh(user)
        return user
