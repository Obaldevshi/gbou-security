"""Pseudonymous routing only; never store source logins or password material."""
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, UniqueConstraint
from .base import Base


class LoginDirectoryEntry(Base):
    __tablename__ = 'login_directory_entries'
    __table_args__ = (UniqueConstraint('school_id', 'lookup_tag', name='uq_login_directory_school_tag'),)
    school_id = Column(Integer, ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True)
    lookup_tag = Column(String(64), nullable=False, index=True)
    generation = Column(Integer, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
