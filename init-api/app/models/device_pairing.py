from sqlalchemy import CheckConstraint, Column, DateTime, Integer, String
from .base import Base


class DevicePairing(Base):
    __tablename__ = 'device_pairings'
    __table_args__ = (CheckConstraint("state IN ('waiting','approved','completed','expired')", name='ck_pairing_state'),)
    request_id = Column(String(36), nullable=False, unique=True)
    device_id = Column(String(36), nullable=False, unique=True)
    label = Column(String(80), nullable=False)
    public_key = Column(String(44), nullable=False)
    poll_hash = Column(String(64), nullable=False)
    code_hash = Column(String(64), nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    state = Column(String(12), nullable=False, default='waiting')
    failed_checks = Column(Integer, nullable=False, default=0)
