from datetime import datetime

from pydantic import BaseModel


class LocalNodeStatus(BaseModel):
    sd_free_mb: int
    usb_connected: bool
    usb_free_mb: int | None
    last_backup_at: datetime | None
    last_config_sync_at: datetime | None
    warnings: list[str]


class LocalNodeStatusEnvelope(BaseModel):
    message: str
    data: LocalNodeStatus
