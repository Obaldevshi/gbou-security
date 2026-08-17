from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import ExitRequest, ExitRequestStatus, SchoolClass, Student, TeacherClassAssignment


class SchoolClassAdminRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int, building_id: int | None = None) -> list[SchoolClass]:
        query = self.db.query(SchoolClass).options(joinedload(SchoolClass.building)).filter(SchoolClass.school_id == school_id)
        if building_id is not None:
            query = query.filter(SchoolClass.building_id == building_id)
        return query.order_by(SchoolClass.name.asc()).all()

    def get_for_school(self, class_id: int, school_id: int) -> SchoolClass | None:
        return self.db.query(SchoolClass).filter(SchoolClass.id == class_id, SchoolClass.school_id == school_id).first()

    def name_exists(self, building_id: int, name: str, exclude_id: int | None = None) -> bool:
        query = self.db.query(SchoolClass.id).filter(SchoolClass.building_id == building_id, SchoolClass.name == name)
        if exclude_id is not None:
            query = query.filter(SchoolClass.id != exclude_id)
        return query.first() is not None

    def building_exists(self, school_id: int, building_id: int) -> bool:
        from app.models.school_building import SchoolBuilding
        return self.db.query(SchoolBuilding.id).filter(
            SchoolBuilding.id == building_id,
            SchoolBuilding.school_id == school_id,
        ).first() is not None

    def add(self, school_class: SchoolClass) -> None:
        self.db.add(school_class)

    def delete_with_dependencies(self, school_class: SchoolClass) -> None:
        class_id = school_class.id
        self.db.query(ExitRequest).filter(ExitRequest.class_id == class_id).delete(synchronize_session=False)
        self.db.query(TeacherClassAssignment).filter(TeacherClassAssignment.class_id == class_id).delete(synchronize_session=False)
        self.db.query(Student).filter(Student.class_id == class_id).delete(synchronize_session=False)
        self.db.delete(school_class)

    def cancel_pending_requests(self, class_id: int) -> None:
        self.db.query(ExitRequest).filter(
            ExitRequest.class_id == class_id,
            ExitRequest.status == ExitRequestStatus.PENDING,
        ).update(
            {ExitRequest.status: ExitRequestStatus.CANCELLED},
            synchronize_session=False,
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, school_class: SchoolClass) -> SchoolClass:
        self.db.refresh(school_class)
        return school_class
