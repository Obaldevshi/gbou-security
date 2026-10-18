"""Short-lived control-plane auth, deliberately incompatible with school JWTs."""
from datetime import datetime, timedelta, timezone
import hashlib
from jose import JWTError, jwt
from app.config.settings import settings
from app.core.exceptions import ForbiddenError, UnauthorizedError, ValidationError
from app.core.security import verify_password, get_password_hash
from app.models.user import UserRole
from .device_pairing_service import DevicePairingService
from .login_attempt_guard import LoginAttemptGuard

device_admin_guard = LoginAttemptGuard()


def require_device_admin(user, *, allow_temporary=False):
    if user is None or not user.is_active or user.role not in {UserRole.SCHOOL_ADMIN, UserRole.SUPER_ADMIN}:
        raise UnauthorizedError('Войдите учётной записью администратора')
    if user.must_change_password and not allow_temporary:
        raise ForbiddenError('Сначала смените временный пароль в обычном кабинете')
    if user.role == UserRole.SCHOOL_ADMIN and (not user.school or not user.school.is_active):
        raise ForbiddenError('Школа отключена')
    return user


class DeviceAdminService:
    def __init__(self, users):
        self.users = users

    def login(self, payload):
        DevicePairingService.enabled()
        login = payload.login.strip().lower()
        with device_admin_guard.attempt(login):
            user = self.users.get_by_login(login)
            if not user or not verify_password(payload.password, user.hashed_password):
                raise UnauthorizedError('Неверный логин или пароль')
            require_device_admin(user, allow_temporary=True)
        return self.session(user)

    def session(self, user):
        claims = {'sub': str(user.id), 'aud': 'device-onboarding',
                  'iss': 'gbou-device-onboarding', 'scope': 'devices:password' if user.must_change_password else 'devices:manage',
                  'pwdv': hashlib.sha256(user.hashed_password.encode()).hexdigest(),
                  'exp': datetime.now(timezone.utc) + timedelta(minutes=5)}
        return {'access_token': jwt.encode(claims, settings.secret_key, algorithm=settings.algorithm),
                'expires_in': 300, 'password_change_required': user.must_change_password}

    def authenticate(self, token, *, allow_password_change=False):
        DevicePairingService.enabled()
        try:
            claims = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm],
                                audience='device-onboarding', issuer='gbou-device-onboarding',
                                options={'require_exp': True, 'require_sub': True})
            user = require_device_admin(self.users.get_by_id(int(claims['sub'])), allow_temporary=True)
            expected = 'devices:password' if user.must_change_password else 'devices:manage'
            if claims['scope'] != expected:
                raise ValueError('Invalid scope')
            if claims['pwdv'] != hashlib.sha256(user.hashed_password.encode()).hexdigest():
                raise ValueError('Password changed')
            if user.must_change_password and not allow_password_change:
                raise ForbiddenError('Сначала смените временный пароль', code='password_change_required')
            return user
        except (JWTError, AssertionError, KeyError, ValueError, TypeError):
            raise UnauthorizedError('Вход для подключения истёк. Войдите снова', code='pairing_session_expired')

    def change_password(self, token, payload):
        user = self.authenticate(token, allow_password_change=True)
        if verify_password(payload.new_password, user.hashed_password):
            raise ValidationError('Новый пароль должен отличаться от прежнего')
        user.hashed_password = get_password_hash(payload.new_password)
        user.must_change_password = False
        self.users.commit()
        return self.session(user)
