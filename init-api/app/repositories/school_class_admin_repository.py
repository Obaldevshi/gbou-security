from sqlalchemy.orm import Session

from app.models.exit_request import ExitRequest, SchoolClass, Student, TeacherClassAssignment


class SchoolClassAdminRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int) -> list[SchoolClass]:
        return self.db.query(SchoolClass).filter(SchoolClass.school_id == school_id).order_by(SchoolClass.name.asc()).all()

    def get_for_school(self, class_id: int, school_id: int) -> SchoolClass | None:
        return self.db.query(SchoolClass).filter(SchoolClass.id == class_id, SchoolClass.school_id == school_id).first()

    def name_exists(self, school_id: int, name: str, exclude_id: int | None = None) -> bool:
        query = self.db.query(SchoolClass.id).filter(SchoolClass.school_id == school_id, SchoolClass.name == name)
        if exclude_id is not None:
            query = query.filter(SchoolClass.id != exclude_id)
        return query.first() is not None

    def add(self, school_class: SchoolClass) -> None:
        self.db.add(school_class)

    def delete_with_dependencies(self, school_class: SchoolClass) -> None:
        class_id = school_class.id
        self.db.query(ExitRequest).filter(ExitRequest.class_id == class_id).delete(synchronize_session=False)
        self.db.query(TeacherClassAssignment).filter(TeacherClassAssignment.class_id == class_id).delete(synchronize_session=False)
        self.db.query(Student).filter(Student.class_id == class_id).delete(synchronize_session=False)
        self.db.delete(school_class)

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, school_class: SchoolClass) -> SchoolClass:
        self.db.refresh(school_class)
        return school_class
