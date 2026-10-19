from datetime import datetime, timezone
from app.models.user import User, UserRole
from app.models.category import Category
from app.models.exit_request import TeacherClassAssignment
from app.models.trusted_device_session import TrustedDeviceSession
from app.models.audit_log import AuditLog


class AccountDeletionRepository:
    def __init__(self, db):
        self.db = db

    def lock_user(self, user_id: int) -> User | None:
        return self.db.query(User).filter(User.id == user_id).with_for_update().populate_existing().first()

    def has_other_admin(self, user: User, *, lock=False) -> bool:
        if user.role not in {UserRole.SUPER_ADMIN, UserRole.SCHOOL_ADMIN}:
            return True
        query = self.db.query(User).filter(User.role == user.role, User.is_active.is_(True), User.deleted_at.is_(None))
        if user.role == UserRole.SCHOOL_ADMIN:
            query = query.filter(User.school_id == user.school_id)
        if lock:
            # Stable lock order prevents two administrators deleting the last pair.
            query.order_by(User.id).with_for_update().all()
        return query.filter(User.id != user.id).first() is not None

    def erase_personal_links(self, user: User) -> None:
        self.db.query(TrustedDeviceSession).filter(TrustedDeviceSession.user_id == user.id).delete(synchronize_session=False)
        self.db.query(TeacherClassAssignment).filter(TeacherClassAssignment.teacher_id == user.id).delete(synchronize_session=False)
        self.db.query(Category).filter(Category.user_id == user.id).delete(synchronize_session=False)
        self.db.query(AuditLog).filter(AuditLog.actor_id == user.id).update({
            AuditLog.actor_id: None, AuditLog.ip_address: None, AuditLog.user_agent: None,
        }, synchronize_session=False)

    def anonymize(self, user: User, login: str, password_hash: str) -> None:
        self.erase_personal_links(user)
        user.login = login
        user.full_name = 'Удалённый сотрудник'
        user.phone = None
        user.hashed_password = password_hash
        user.password_reset_marker = None
        user.is_active = False
        user.must_change_password = False
        user.deleted_at = datetime.now(timezone.utc)
        self.db.add(AuditLog(actor_id=None, school_id=user.school_id, method='DELETE',
                            path='/api/v1/users/delete-account', status_code=200))

    def commit(self):
        self.db.commit()

    def rollback(self):
        self.db.rollback()
