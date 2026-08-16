from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.audit_log import AuditLog
from app.models.user import User


class AuditLogRepository:
    def __init__(self, db: Session):
        self.db = db

    def add(self, log: AuditLog) -> None:
        self.db.add(log)
        self.db.commit()

    def list(
        self,
        *,
        school_id: int | None,
        page: int,
        page_size: int,
        search: str | None,
        method: str | None,
    ) -> tuple[list[AuditLog], int]:
        query = self.db.query(AuditLog).options(
            joinedload(AuditLog.actor),
            joinedload(AuditLog.school),
        )
        if school_id is not None:
            query = query.filter(AuditLog.school_id == school_id)
        if method:
            query = query.filter(AuditLog.method == method.upper())
        if search:
            pattern = f"%{search.strip().lower()}%"
            query = query.outerjoin(AuditLog.actor).filter(
                or_(
                    func.lower(AuditLog.path).like(pattern),
                    func.lower(func.coalesce(User.full_name, "")).like(pattern),
                    func.lower(func.coalesce(User.login, "")).like(pattern),
                )
            )
        total = query.count()
        items = (
            query.order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
            .all()
        )
        return items, total
