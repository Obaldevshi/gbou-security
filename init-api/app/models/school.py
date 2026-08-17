from sqlalchemy import Boolean, Column, String
from sqlalchemy.orm import relationship

from .base import Base


class School(Base):
    __tablename__ = "schools"

    full_name = Column(String, nullable=False)
    short_name = Column(String, nullable=False)
    address = Column(String, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)

    users = relationship("User", back_populates="school")
    buildings = relationship("SchoolBuilding", back_populates="school")
    classes = relationship("SchoolClass", back_populates="school")
    students = relationship("Student", back_populates="school")
    exit_requests = relationship("ExitRequest", back_populates="school")
