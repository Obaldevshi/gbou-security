from enum import StrEnum

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Integer, String
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
    # Synced central administrators may use negative IDs to avoid collisions.
    # SQLite AUTOINCREMENT keeps newly created local users positive even when
    # the database initially contains only negative administrator IDs.
    __table_args__ = {"sqlite_autoincrement": True}

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=True, index=True)
    building_id = Column(
        Integer,
        ForeignKey("school_buildings.id"),
        nullable=True,
        index=True,
    )
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
    must_change_password = Column(Boolean, nullable=False, default=True)
    password_reset_marker = Column(String(64), nullable=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    school = relationship(School, back_populates="users")
    building = relationship("SchoolBuilding", back_populates="users")
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
    trusted_device_sessions = relationship(
        "TrustedDeviceSession",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    @property
    def classes(self):
        return [assignment.school_class for assignment in self.class_assignments]

    @property
    def building_name(self) -> str | None:
        return self.building.name if self.building is not None else None
