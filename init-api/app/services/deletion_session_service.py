"""Two-minute, deletion-only reauthentication for centrally managed admins."""
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from app.config.settings import settings
from app.core.security import verify_password
from app.core.exceptions import UnauthorizedError, ForbiddenError
from app.models.user import UserRole
from app.services.login_attempt_guard import LoginAttemptGuard

deletion_guard = LoginAttemptGuard(attempts=5, window_seconds=60)

class DeletionSessionService:
    def __init__(self, users):
        self.users = users

    @staticmethod
    def _allowed(user):
        return (user is not None and user.is_active and user.deleted_at is None
                and user.role in {UserRole.SCHOOL_ADMIN, UserRole.SUPER_ADMIN}
                and (user.school_id is None or (user.school is not None and user.school.is_active)))

    def login(self, login, password):
        if settings.deployment_mode not in {'cloud', 'legacy'}:
            raise ForbiddenError('Используйте центральный сервис', code='central_account_required')
        with deletion_guard.attempt(login):
            user = self.users.get_by_login(login)
            if not self._allowed(user) or not verify_password(password, user.hashed_password):
                raise UnauthorizedError('Неверный логин или пароль', code='invalid_credentials')
            token = jwt.encode({'sub': f'account-delete:{user.id}', 'purpose':'account-deletion',
                'exp': datetime.now(timezone.utc) + timedelta(seconds=120)},
                settings.secret_key, algorithm=settings.algorithm)
            return {'access_token':token, 'expires_in':120,
                    'user':{'id':user.id, 'role':user.role.value, 'school_id':user.school_id}}

    def authenticate(self, token):
        if settings.deployment_mode not in {'cloud', 'legacy'}:
            raise ForbiddenError('Используйте центральный сервис', code='central_account_required')
        try:
            payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
            subject = payload.get('sub','')
            if payload.get('purpose') != 'account-deletion' or not subject.startswith('account-delete:'):
                raise ValueError()
            user = self.users.get_by_id(int(subject.split(':',1)[1]))
            if not self._allowed(user):
                raise ValueError()
            return user
        except (JWTError, ValueError, TypeError, AttributeError):
            raise UnauthorizedError('Подтвердите пароль повторно', code='deletion_session_expired')
