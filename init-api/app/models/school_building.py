from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from .base import Base


class SchoolBuilding(Base):
    __tablename__ = "school_buildings"
    __table_args__ = (
        UniqueConstraint("school_id", "name", name="uq_school_buildings_school_name"),
    )

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    address = Column(String(255), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)

    school = relationship("School", back_populates="buildings")
    classes = relationship("SchoolClass", back_populates="building")
    users = relationship("User", back_populates="building")
    exit_requests = relationship("ExitRequest", back_populates="building")
