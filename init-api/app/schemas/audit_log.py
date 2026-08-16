from datetime import datetime

from pydantic import BaseModel


class AuditLogResponse(BaseModel):
    id: int
    actor_id: int | None
    actor_name: str
    actor_role: str | None
    school_id: int | None
    school_name: str | None
    method: str
    path: str
    status_code: int
    ip_address: str | None
    created_at: datetime


class AuditLogPage(BaseModel):
    items: list[AuditLogResponse]
    total: int
    page: int
    page_size: int


class AuditLogEnvelope(BaseModel):
    message: str
    data: AuditLogPage
