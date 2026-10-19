"""School-scoped retention queries; no filesystem or transaction ownership."""
from sqlalchemy import or_, text

from app.models.school import School
from app.models.audit_log import AuditLog
from app.models.exit_request import ExitRequest, ExitRequestStatus


class RetentionRepository:
    def __init__(self, db):
        self.db = db

    def require_single_school(self, school_id):
        if school_id <= 0 or self.db.query(School.id).all() != [(school_id,)]:
            raise ValueError('Очистка допустима только для единственной школы локального узла')

    def _requests(self, school_id, cutoff):
        return self.db.query(ExitRequest).filter(
            ExitRequest.school_id == school_id,
            ExitRequest.status.in_((ExitRequestStatus.RELEASED, ExitRequestStatus.CANCELLED, ExitRequestStatus.EXPIRED)),
            ExitRequest.created_at < cutoff,
            ExitRequest.updated_at < cutoff,
            ExitRequest.scheduled_at < cutoff,
            or_(ExitRequest.released_at.is_(None), ExitRequest.released_at < cutoff),
        )

    def _audit(self, school_id, cutoff):
        return self.db.query(AuditLog).filter(AuditLog.school_id == school_id, AuditLog.created_at < cutoff)

    def counts(self, school_id, cutoff):
        return {'requests': self._requests(school_id, cutoff).count(), 'audit': self._audit(school_id, cutoff).count()}

    def delete_expired(self, school_id, cutoff):
        if self.db.get_bind().dialect.name == 'sqlite':
            self.db.execute(text('PRAGMA secure_delete=ON'))
        return {
            'requests': self._requests(school_id, cutoff).delete(synchronize_session=False),
            'audit': self._audit(school_id, cutoff).delete(synchronize_session=False),
        }

    def commit(self):
        self.db.commit()

    def rollback(self):
        self.db.rollback()
