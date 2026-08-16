from app.repositories.audit_log_repository import AuditLogRepository
from app.schemas.audit_log import AuditLogPage, AuditLogResponse


class AuditLogService:
    def __init__(self, repository: AuditLogRepository):
        self.repository = repository

    def list(self, *, school_id: int | None, page: int, page_size: int, search: str | None, method: str | None) -> AuditLogPage:
        items, total = self.repository.list(
            school_id=school_id,
            page=page,
            page_size=page_size,
            search=search,
            method=method,
        )
        return AuditLogPage(
            items=[
                AuditLogResponse(
                    id=item.id,
                    actor_id=item.actor_id,
                    actor_name=item.actor.full_name if item.actor else "Удалённый пользователь",
                    actor_role=item.actor.role.value if item.actor else None,
                    school_id=item.school_id,
                    school_name=item.school.short_name if item.school else None,
                    method=item.method,
                    path=item.path,
                    status_code=item.status_code,
                    ip_address=item.ip_address,
                    created_at=item.created_at,
                )
                for item in items
            ],
            total=total,
            page=page,
            page_size=page_size,
        )
