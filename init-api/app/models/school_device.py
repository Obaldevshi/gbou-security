"""Cloud-only control-plane metadata. Never store school personal records here."""
from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, String
from .base import Base


class SchoolEndpoint(Base):
    __tablename__ = 'school_endpoints'
    school_id = Column(Integer, ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, unique=True)
    slug = Column(String(63), nullable=False, unique=True)
    generation = Column(Integer, nullable=False, default=0)
    primary_device_id = Column(String(36), nullable=True, unique=True)


class SchoolDevice(Base):
    __tablename__ = 'school_devices'
    __table_args__ = (
        CheckConstraint("role IN ('primary', 'terminal')", name='ck_device_role'),
        CheckConstraint("state IN ('pending', 'active', 'revoked')", name='ck_device_state'),
    )
    school_id = Column(Integer, ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True)
    building_id = Column(Integer, ForeignKey('school_buildings.id', ondelete='SET NULL'), nullable=True)
    device_id = Column(String(36), nullable=False, unique=True)
    label = Column(String(80), nullable=False)
    role = Column(String(12), nullable=False)
    state = Column(String(12), nullable=False, default='pending')
    token_hash = Column(String(64), nullable=False, unique=True)
    public_key = Column(String(44), nullable=True, unique=True)
    tunnel_ip = Column(String(15), nullable=True, unique=True)
    last_seen_at = Column(DateTime, nullable=True)
    generation = Column(Integer, nullable=False)


class DeviceInvitation(Base):
    __tablename__ = 'device_invitations'
    school_id = Column(Integer, ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True)
    role = Column(String(12), nullable=False)
    generation = Column(Integer, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    consumed_at = Column(DateTime, nullable=True)
    device_id = Column(String(36), nullable=True)
    revoked = Column(Boolean, nullable=False, default=False)
