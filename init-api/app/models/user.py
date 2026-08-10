from enum import StrEnum

from sqlalchemy import Boolean, Column, Enum, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from .base import Base
from .school import School


class UserRole(StrEnum):
    SUPER_ADMIN = "super_admin"
    SCHOOL_ADMIN = "school_admin"
    TEACHER = "teacher"
    GUARD = "guard"


class User(Base):
    __tablename__ = "users"

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=True, index=True)
    login = Column(String, unique=True, nullable=False, index=True)
    full_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    role = Column(
        Enum(
            UserRole,
            name="user_role",
            values_callable=lambda roles: [role.value for role in roles],
        ),
        nullable=False,
    )
    is_active = Column(Boolean, nullable=False, default=True)

    school = relationship(School, back_populates="users")
    categories = relationship("Category", back_populates="user", cascade="all, delete-orphan")
    class_assignments = relationship(
        "TeacherClassAssignment",
        back_populates="teacher",
        cascade="all, delete-orphan",
    )
    created_exit_requests = relationship(
        "ExitRequest",
        foreign_keys="ExitRequest.teacher_id",
        back_populates="teacher",
    )
    released_exit_requests = relationship(
        "ExitRequest",
        foreign_keys="ExitRequest.released_by_id",
        back_populates="released_by",
    )
