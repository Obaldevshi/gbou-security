from app.constants.messages import AuthMessages
from app.core.exceptions import NotFoundError, UnauthorizedError, UnprocessableEntityError
from app.core.security import get_password_hash, verify_password
from app.models.user import User
from app.repositories.user_repository import UserRepository


class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository

    def get_user_by_id(self, user_id: int) -> User:
        user = self.repository.get_by_id(user_id)
        if not user:
            raise NotFoundError(AuthMessages.USER_NOT_FOUND.value)
        return user

    def change_password(
        self,
        user: User,
        current_password: str,
        new_password: str,
    ) -> None:
        if not verify_password(current_password, user.hashed_password):
            raise UnauthorizedError(
                "Текущий пароль указан неверно",
                code="invalid_current_password",
            )
        if current_password == new_password:
            raise UnprocessableEntityError(
                "Новый пароль должен отличаться от текущего",
                code="password_unchanged",
            )
        try:
            user.hashed_password = get_password_hash(new_password)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise
