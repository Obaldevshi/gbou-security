from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.exit_request import (
    ExitRequest,
    ExitRequestStatus,
    SchoolClass,
    Student,
    TeacherClassAssignment,
)
from app.models.school import School
from app.models.user import User, UserRole


class SchoolRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_all(self) -> list[School]:
        return self.db.query(School).order_by(School.short_name.asc()).all()

    def get_by_id(self, school_id: int) -> School | None:
        return self.db.query(School).filter(School.id == school_id).first()

    def has_name_conflict(
        self,
        *,
        full_name: str,
        short_name: str,
        exclude_school_id: int | None = None,
    ) -> bool:
        query = self.db.query(School.id).filter(
            or_(
                func.lower(School.full_name) == full_name.lower(),
                func.lower(School.short_name) == short_name.lower(),
            )
        )
        if exclude_school_id is not None:
            query = query.filter(School.id != exclude_school_id)
        return query.first() is not None

    def add(self, school: School) -> School:
        self.db.add(school)
        self.db.flush()
        return school

    def delete_with_dependencies(self, school: School) -> None:
        school_id = school.id
        class_ids = self.db.query(SchoolClass.id).filter(
            SchoolClass.school_id == school_id
        )
        user_ids = self.db.query(User.id).filter(User.school_id == school_id)
        self.db.query(ExitRequest).filter(
            ExitRequest.school_id == school_id
        ).delete(synchronize_session=False)
        self.db.query(TeacherClassAssignment).filter(
            or_(
                TeacherClassAssignment.class_id.in_(class_ids),
                TeacherClassAssignment.teacher_id.in_(user_ids),
            )
        ).delete(synchronize_session=False)
        self.db.query(Student).filter(Student.school_id == school_id).delete(
            synchronize_session=False
        )
        self.db.query(SchoolClass).filter(
            SchoolClass.school_id == school_id
        ).delete(synchronize_session=False)
        self.db.query(User).filter(User.school_id == school_id).delete(
            synchronize_session=False
        )
        self.db.delete(school)

    def cancel_pending_requests(self, school_id: int) -> None:
        self.db.query(ExitRequest).filter(
            ExitRequest.school_id == school_id,
            ExitRequest.status == ExitRequestStatus.PENDING,
        ).update(
            {ExitRequest.status: ExitRequestStatus.CANCELLED},
            synchronize_session=False,
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, school: School) -> School:
        self.db.refresh(school)
        return school

    def get_system_stats(self) -> dict[str, int]:
        schools = self.db.query(func.count(School.id)).scalar() or 0
        active_schools = (
            self.db.query(func.count(School.id))
            .filter(School.is_active.is_(True))
            .scalar()
            or 0
        )
        school_admins = (
            self.db.query(func.count(User.id))
            .filter(User.role == UserRole.SCHOOL_ADMIN)
            .scalar()
            or 0
        )
        users = (
            self.db.query(func.count(User.id))
            .filter(User.role != UserRole.SUPER_ADMIN)
            .scalar()
            or 0
        )
        return {
            "schools": schools,
            "active_schools": active_schools,
            "school_admins": school_admins,
            "users": users,
        }
