from app.config.settings import settings
from app.constants.messages import AuthMessages
from datetime import datetime, timedelta, timezone
import hashlib
import secrets

from app.core.exceptions import BaseError, ForbiddenError, NotFoundError, UnauthorizedError
from app.core.security import create_access_token, verify_password
from app.models.trusted_device_session import TrustedDeviceSession
from app.models.user import User, UserRole
from app.repositories.trusted_device_session_repository import (
    TrustedDeviceSessionRepository,
)
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    LoginRequest,
    TokenResponse,
    TrustedDeviceCreatedResponse,
    TrustedDeviceResponse,
    TrustedSessionResponse,
)
from app.schemas.user import CurrentUserResponse
from app.services.login_attempt_guard import school_login_guard


SCHOOL_ROLES = {UserRole.SCHOOL_ADMIN, UserRole.TEACHER, UserRole.GUARD}


class AuthService:
    def __init__(
        self,
        repository: UserRepository,
        trusted_devices: TrustedDeviceSessionRepository,
    ):
        self.repository = repository
        self.trusted_devices = trusted_devices

    def authenticate_user(self, login_data: LoginRequest) -> TokenResponse:
        if settings.deployment_mode == 'local':
            with school_login_guard.attempt(login_data.login):
                return self._authenticate_user(login_data)
        return self._authenticate_user(login_data)

    def _authenticate_user(self, login_data: LoginRequest) -> TokenResponse:
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

    def create_trusted_device(
        self,
        user: User,
        device_name: str,
    ) -> TrustedDeviceCreatedResponse:
        if user.must_change_password:
            raise ForbiddenError(
                "Сначала смените временный пароль",
                code="password_change_required",
            )
        self.ensure_user_can_access(user)
        now = datetime.now(timezone.utc)
        raw_token = self._new_refresh_token()
        session = TrustedDeviceSession(
            user_id=user.id,
            name=device_name,
            token_hash=self._digest(raw_token),
            expires_at=now + timedelta(days=settings.trusted_device_expire_days),
        )
        try:
            self.trusted_devices.create(session)
            active = self.trusted_devices.list_active_for_user(user.id)
            for old_session in active[10:]:
                old_session.revoked_at = now
            self.trusted_devices.commit()
            self.trusted_devices.refresh(session)
        except Exception:
            self.trusted_devices.rollback()
            raise
        return TrustedDeviceCreatedResponse(
            id=session.id,
            name=session.name,
            expires_at=session.expires_at,
            last_used_at=session.last_used_at,
            created_at=session.created_at,
            refresh_token=raw_token,
        )

    def refresh_trusted_device(self, refresh_token: str) -> TrustedSessionResponse:
        session = self.trusted_devices.get_by_token_hash_for_update(
            self._digest(refresh_token),
        )
        now = datetime.now(timezone.utc)
        if session is None or session.revoked_at is not None:
            raise UnauthorizedError(
                "Доверенная сессия недействительна",
                code="trusted_session_invalid",
            )
        if self._as_utc(session.expires_at) <= now:
            session.revoked_at = now
            self.trusted_devices.commit()
            raise UnauthorizedError(
                "Срок доверенной сессии истёк",
                code="trusted_session_expired",
            )

        user = self.repository.get_by_id(session.user_id)
        if user is None:
            session.revoked_at = now
            self.trusted_devices.commit()
            raise UnauthorizedError(
                "Доверенная сессия недействительна",
                code="trusted_session_invalid",
            )
        self.ensure_user_can_access(user)
        if user.must_change_password:
            raise ForbiddenError(
                "Сначала смените временный пароль",
                code="password_change_required",
            )

        rotated_token = self._new_refresh_token()
        session.token_hash = self._digest(rotated_token)
        session.last_used_at = now
        try:
            self.trusted_devices.commit()
        except Exception:
            self.trusted_devices.rollback()
            raise
        return TrustedSessionResponse(
            access_token=create_access_token(user.id),
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60,
            user=CurrentUserResponse.model_validate(user),
            refresh_token=rotated_token,
            trusted_device_id=session.id,
        )

    def revoke_by_token(self, refresh_token: str) -> None:
        session = self.trusted_devices.get_by_token_hash_for_update(
            self._digest(refresh_token),
        )
        if session is None or session.revoked_at is not None:
            return
        session.revoked_at = datetime.now(timezone.utc)
        try:
            self.trusted_devices.commit()
        except Exception:
            self.trusted_devices.rollback()
            raise

    def list_trusted_devices(self, user: User) -> list[TrustedDeviceResponse]:
        self.ensure_user_can_access(user)
        return [
            TrustedDeviceResponse.model_validate(item)
            for item in self.trusted_devices.list_active_for_user(user.id)
        ]

    def revoke_trusted_device(self, user: User, session_id: int) -> None:
        session = self.trusted_devices.get_active_for_user(user.id, session_id)
        if session is None:
            raise NotFoundError("Доверенное устройство не найдено")
        session.revoked_at = datetime.now(timezone.utc)
        try:
            self.trusted_devices.commit()
        except Exception:
            self.trusted_devices.rollback()
            raise

    @staticmethod
    def _new_refresh_token() -> str:
        return secrets.token_urlsafe(48)

    @staticmethod
    def _digest(value: str) -> str:
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    @staticmethod
    def ensure_user_can_access(user: User) -> None:
        if getattr(user, 'deleted_at', None) is not None:
            raise UnauthorizedError('Аккаунт удалён', code='account_deleted')
        if (
            settings.deployment_mode == 'legacy'
            and settings.migration_freeze_writes
            and user.role in SCHOOL_ROLES
        ):
            error = BaseError(
                'Школьные изменения временно приостановлены для переноса данных',
                503, 'school_migration_freeze',
            )
            error.headers = {'Retry-After': '300'}
            raise error
        if settings.deployment_mode == "cloud" and user.role in SCHOOL_ROLES:
            raise ForbiddenError("Откройте адрес сервиса своей школы. В приложении выберите «Подключение к школе» перед входом.", code="local_access_required")
        if settings.deployment_mode == "local" and user.role == UserRole.SUPER_ADMIN:
            raise ForbiddenError("Главный администратор входит через центральный сайт", code="cloud_access_required")
        if settings.deployment_mode == 'local' and settings.gbou_building_id is not None:
            building = getattr(user, 'building_id', None)
            if (building != settings.gbou_building_id
                    and not (building is None and user.role == UserRole.SCHOOL_ADMIN)):
                raise ForbiddenError('Откройте сервер своего корпуса', code='building_scope_mismatch')
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
            if (
                settings.deployment_mode == "local"
                and user.role in {UserRole.TEACHER, UserRole.GUARD}
                and user.building is not None
                and not user.building.is_active
            ):
                raise ForbiddenError(
                    "Корпус отключён главным администратором",
                    code="building_inactive",
                )
