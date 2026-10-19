import secrets
from app.core.exceptions import ConflictError, UnauthorizedError, UnprocessableEntityError
from app.core.security import get_password_hash, verify_password
from app.models.user import UserRole
from app.services.deletion_session_service import deletion_guard


class AccountDeletionService:
    def __init__(self, repository, deployment_mode: str):
        self.repository = repository
        self.mode = deployment_mode

    def info(self, user):
        central = self.mode == 'local' and user.role in {UserRole.SCHOOL_ADMIN, UserRole.SUPER_ADMIN}
        return {'authority': 'central' if central else 'current',
                'user_id': abs(user.id) if central else user.id,
                'can_delete': central or self.repository.has_other_admin(user),
                'history_preserved': True, 'backups_not_rewritten': True}

    def delete(self, current_user, password: str, confirmation: str):
        with deletion_guard.attempt(f'delete-own:{current_user.id}'):
            return self._delete(current_user, password, confirmation)

    def _delete(self, current_user, password: str, confirmation: str):
        if confirmation != 'УДАЛИТЬ':
            raise UnprocessableEntityError('Введите УДАЛИТЬ для подтверждения', code='deletion_confirmation_required')
        if self.info(current_user)['authority'] == 'central':
            raise ConflictError('Этот аккаунт удаляется в центральном сервисе', code='central_account_required')
        # Verify before role locking to avoid holding locks while hashing password.
        if not verify_password(password, current_user.hashed_password):
            raise UnauthorizedError('Текущий пароль указан неверно', code='invalid_current_password')
        try:
            if not self.repository.has_other_admin(current_user, lock=True):
                raise ConflictError('Сначала назначьте другого активного администратора', code='last_administrator')
            user = self.repository.lock_user(current_user.id)
            if user is None or user.deleted_at is not None or not user.is_active:
                raise UnauthorizedError('Аккаунт уже удалён или отключён', code='account_deleted')
            if not verify_password(password, user.hashed_password):
                raise UnauthorizedError('Текущий пароль указан неверно', code='invalid_current_password')
            self.repository.anonymize(user, 'deleted-' + secrets.token_hex(24),
                                      get_password_hash(secrets.token_urlsafe(36)))
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise
