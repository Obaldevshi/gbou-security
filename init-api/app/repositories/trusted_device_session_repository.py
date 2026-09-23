from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.trusted_device_session import TrustedDeviceSession


class TrustedDeviceSessionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, session: TrustedDeviceSession) -> TrustedDeviceSession:
        self.db.add(session)
        self.db.flush()
        return session

    def get_by_token_hash_for_update(
        self,
        token_hash: str,
    ) -> TrustedDeviceSession | None:
        return (
            self.db.query(TrustedDeviceSession)
            .filter(TrustedDeviceSession.token_hash == token_hash)
            .with_for_update()
            .one_or_none()
        )

    def list_active_for_user(self, user_id: int) -> list[TrustedDeviceSession]:
        now = datetime.now(timezone.utc)
        return (
            self.db.query(TrustedDeviceSession)
            .filter(
                TrustedDeviceSession.user_id == user_id,
                TrustedDeviceSession.revoked_at.is_(None),
                TrustedDeviceSession.expires_at > now,
            )
            .order_by(
                func.coalesce(
                    TrustedDeviceSession.last_used_at,
                    TrustedDeviceSession.created_at,
                ).desc(),
                TrustedDeviceSession.id.desc(),
            )
            .all()
        )

    def get_active_for_user(
        self,
        user_id: int,
        session_id: int,
    ) -> TrustedDeviceSession | None:
        return (
            self.db.query(TrustedDeviceSession)
            .filter(
                TrustedDeviceSession.id == session_id,
                TrustedDeviceSession.user_id == user_id,
                TrustedDeviceSession.revoked_at.is_(None),
            )
            .one_or_none()
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, session: TrustedDeviceSession) -> TrustedDeviceSession:
        self.db.refresh(session)
        return session
