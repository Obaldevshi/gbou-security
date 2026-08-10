from app.config.settings import settings
from app.constants.messages import AuthMessages
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.security import create_access_token, verify_password
from app.models.user import User, UserRole
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import CurrentUserResponse


SCHOOL_ROLES = {UserRole.SCHOOL_ADMIN, UserRole.TEACHER, UserRole.GUARD}


class AuthService:
    def __init__(self, repository: UserRepository):
        self.repository = repository

    def authenticate_user(self, login_data: LoginRequest) -> TokenResponse:
        user = self.repository.get_by_login(login_data.login)

        if not user or not verify_password(login_data.password, user.hashed_password):
            raise UnauthorizedError(
                AuthMessages.INVALID_CREDENTIALS.value,
                code="invalid_credentials",
            )

        self.ensure_user_can_access(user)
        access_token = create_access_token(user.id)

        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60,
            user=CurrentUserResponse.model_validate(user),
        )

    @staticmethod
    def ensure_user_can_access(user: User) -> None:
        if not user.is_active:
            raise ForbiddenError(
                AuthMessages.ACCOUNT_INACTIVE.value,
                code="account_inactive",
            )

        if user.role in SCHOOL_ROLES:
            if user.school_id is None or user.school is None:
                raise ForbiddenError(
                    AuthMessages.SCHOOL_REQUIRED.value,
                    code="school_required",
                )
            if not user.school.is_active:
                raise ForbiddenError(
                    AuthMessages.SCHOOL_INACTIVE.value,
                    code="school_inactive",
                )
