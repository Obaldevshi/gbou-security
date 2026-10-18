from sqlalchemy import text
from sqlalchemy.orm import Session


class LocalNodeStatusRepository:
    def __init__(self, db: Session):
        self.db = db

    def timestamps(self) -> dict[str, str]:
        return dict(self.db.execute(text(
            "SELECT key, value FROM local_meta WHERE key IN ('last_backup_verified', 'last_config_sync')"
        )).all())
