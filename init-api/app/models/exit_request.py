from enum import StrEnum

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .base import Base


class ExitReasonType(StrEnum):
    PARENT_NOTE = "parent_note"
    HEALTH = "health"
    OTHER = "other"


class ExitRequestStatus(StrEnum):
    PENDING = "pending"
    RELEASED = "released"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class SchoolClass(Base):
    __tablename__ = "school_classes"
    __table_args__ = (
        UniqueConstraint("building_id", "name", name="uq_school_classes_building_name"),
    )

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    building_id = Column(
        Integer,
        ForeignKey("school_buildings.id"),
        nullable=False,
        index=True,
    )
    name = Column(String(64), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)

    school = relationship("School", back_populates="classes")
    building = relationship("SchoolBuilding", back_populates="classes")
    students = relationship("Student", back_populates="school_class")
    teacher_assignments = relationship(
        "TeacherClassAssignment",
        back_populates="school_class",
        cascade="all, delete-orphan",
    )
    exit_requests = relationship("ExitRequest", back_populates="school_class")

    @property
    def building_name(self) -> str:
        return self.building.name


class Student(Base):
    __tablename__ = "students"

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    class_id = Column(
        Integer,
        ForeignKey("school_classes.id"),
        nullable=False,
        index=True,
    )
    last_name = Column(String(100), nullable=False)
    first_name = Column(String(100), nullable=False)
    middle_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    school = relationship("School", back_populates="students")
    school_class = relationship("SchoolClass", back_populates="students")
    exit_requests = relationship("ExitRequest", back_populates="student")

    @property
    def full_name(self) -> str:
        return " ".join(
            part for part in (self.last_name, self.first_name, self.middle_name) if part
        )

    @property
    def class_name(self) -> str:
        return self.school_class.name


class TeacherClassAssignment(Base):
    __tablename__ = "teacher_class_assignments"
    __table_args__ = (
        UniqueConstraint(
            "teacher_id",
            "class_id",
            name="uq_teacher_class_assignments_teacher_class",
        ),
    )

    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    class_id = Column(
        Integer,
        ForeignKey("school_classes.id"),
        nullable=False,
        index=True,
    )

    teacher = relationship("User", back_populates="class_assignments")
    school_class = relationship("SchoolClass", back_populates="teacher_assignments")


class ExitRequest(Base):
    __tablename__ = "exit_requests"
    __table_args__ = (
        Index("ix_exit_requests_teacher_status", "teacher_id", "status"),
        Index(
            "ix_exit_requests_school_status_scheduled",
            "school_id",
            "status",
            "scheduled_at",
        ),
    )

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    building_id = Column(
        Integer,
        ForeignKey("school_buildings.id"),
        nullable=False,
        index=True,
    )
    class_id = Column(
        Integer,
        ForeignKey("school_classes.id"),
        nullable=False,
        index=True,
    )
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    reason_type = Column(
        Enum(
            ExitReasonType,
            name="exit_reason_type",
            values_callable=lambda reasons: [reason.value for reason in reasons],
        ),
        nullable=False,
    )
    custom_reason = Column(String(500), nullable=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=False, index=True)
    status = Column(
        Enum(
            ExitRequestStatus,
            name="exit_request_status",
            values_callable=lambda statuses: [status.value for status in statuses],
        ),
        nullable=False,
        default=ExitRequestStatus.PENDING,
        index=True,
    )
    released_at = Column(DateTime(timezone=True), nullable=True)
    released_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    school = relationship("School", back_populates="exit_requests")
    building = relationship("SchoolBuilding", back_populates="exit_requests")
    school_class = relationship("SchoolClass", back_populates="exit_requests")
    student = relationship("Student", back_populates="exit_requests")
    teacher = relationship(
        "User",
        foreign_keys=[teacher_id],
        back_populates="created_exit_requests",
    )
    released_by = relationship(
        "User",
        foreign_keys=[released_by_id],
        back_populates="released_exit_requests",
    )

    @property
    def class_name(self) -> str:
        return self.school_class.name

    @property
    def student_full_name(self) -> str:
        return self.student.full_name

    @property
    def teacher_full_name(self) -> str:
        return self.teacher.full_name
