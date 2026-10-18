from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from .base import Base


class SchoolNodeCredential(Base):
    __tablename__ = "school_node_credentials"
    __table_args__ = (UniqueConstraint("school_id", name="uq_school_node_credentials_school_id"),)

    school_id = Column(Integer, ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True, index=True)
    is_active = Column(Boolean, nullable=False, default=True)

    school = relationship("School")
