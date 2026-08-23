from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import ExitRequest, ExitRequestStatus, SchoolClass, TeacherClassAssignment
from app.models.user import User, UserRole


class TeacherAdminRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int, building_id: int | None = None) -> list[User]:
        query = (
            self.db.query(User)
            .options(joinedload(User.building))
            .options(joinedload(User.class_assignments).joinedload(TeacherClassAssignment.school_class))
            .filter(User.school_id == school_id, User.role == UserRole.TEACHER)
        )
        if building_id is not None:
            query = query.filter(User.building_id == building_id)
        return query.order_by(User.full_name.asc()).all()

    def get_for_school(self, teacher_id: int, school_id: int) -> User | None:
        return (
            self.db.query(User)
            .options(joinedload(User.building))
            .options(joinedload(User.class_assignments).joinedload(TeacherClassAssignment.school_class))
            .filter(User.id == teacher_id, User.school_id == school_id, User.role == UserRole.TEACHER)
            .first()
        )

    def get_classes_for_school(self, class_ids: list[int], school_id: int, building_id: int) -> list[SchoolClass]:
        return self.db.query(SchoolClass).filter(SchoolClass.school_id == school_id, SchoolClass.building_id == building_id, SchoolClass.id.in_(class_ids)).all()

    def list_classes_for_school(self, school_id: int, building_id: int) -> list[SchoolClass]:
        return self.db.query(SchoolClass).filter(SchoolClass.school_id == school_id, SchoolClass.building_id == building_id).all()

    def building_exists(self, school_id: int, building_id: int) -> bool:
        from app.models.school_building import SchoolBuilding
        return self.db.query(SchoolBuilding.id).filter(SchoolBuilding.id == building_id, SchoolBuilding.school_id == school_id).first() is not None

    def login_exists(self, login: str, exclude_id: int | None = None) -> bool:
        query = self.db.query(User.id).filter(User.login == login.strip().lower())
        if exclude_id is not None:
            query = query.filter(User.id != exclude_id)
        return query.first() is not None

    def add(self, teacher: User) -> None:
        self.db.add(teacher)

    def add_class(self, school_class: SchoolClass) -> SchoolClass:
        self.db.add(school_class)
        self.db.flush()
        return school_class

    def replace_assignments(self, teacher: User, classes: list[SchoolClass]) -> None:
        desired_ids = {item.id for item in classes}
        for assignment in list(teacher.class_assignments):
            if assignment.class_id not in desired_ids:
                teacher.class_assignments.remove(assignment)

        existing_ids = {
            assignment.class_id for assignment in teacher.class_assignments
        }
        teacher.class_assignments.extend(
            TeacherClassAssignment(school_class=item)
            for item in classes
            if item.id not in existing_ids
        )

    def delete_with_requests(self, teacher: User) -> None:
        self.db.query(ExitRequest).filter(ExitRequest.teacher_id == teacher.id).delete(synchronize_session=False)
        self.db.query(TeacherClassAssignment).filter(TeacherClassAssignment.teacher_id == teacher.id).delete(synchronize_session=False)
        self.db.delete(teacher)

    def cancel_pending_requests(self, teacher_id: int) -> None:
        self.db.query(ExitRequest).filter(
            ExitRequest.teacher_id == teacher_id,
            ExitRequest.status == ExitRequestStatus.PENDING,
        ).update(
            {ExitRequest.status: ExitRequestStatus.CANCELLED},
            synchronize_session=False,
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, teacher: User) -> User:
        self.db.refresh(teacher)
        return self.get_for_school(teacher.id, teacher.school_id)
