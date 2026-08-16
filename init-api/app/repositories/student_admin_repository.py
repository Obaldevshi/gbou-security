from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import ExitRequest, ExitRequestStatus, SchoolClass, Student


class StudentAdminRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int, class_id: int | None = None) -> list[Student]:
        query = self.db.query(Student).options(joinedload(Student.school_class)).filter(Student.school_id == school_id)
        if class_id is not None:
            query = query.filter(Student.class_id == class_id)
        return query.order_by(Student.last_name.asc(), Student.first_name.asc()).all()

    def get_for_school(self, student_id: int, school_id: int) -> Student | None:
        return self.db.query(Student).options(joinedload(Student.school_class)).filter(Student.id == student_id, Student.school_id == school_id).first()

    def get_class_for_school(self, class_id: int, school_id: int) -> SchoolClass | None:
        return self.db.query(SchoolClass).filter(SchoolClass.id == class_id, SchoolClass.school_id == school_id).first()

    def list_classes_for_school(self, school_id: int) -> list[SchoolClass]:
        return self.db.query(SchoolClass).filter(SchoolClass.school_id == school_id).all()

    def add(self, student: Student) -> None:
        self.db.add(student)

    def delete_with_requests(self, student: Student) -> None:
        self.db.query(ExitRequest).filter(ExitRequest.student_id == student.id).delete(synchronize_session=False)
        self.db.delete(student)

    def cancel_pending_requests(self, student_id: int) -> None:
        self.db.query(ExitRequest).filter(
            ExitRequest.student_id == student_id,
            ExitRequest.status == ExitRequestStatus.PENDING,
        ).update(
            {ExitRequest.status: ExitRequestStatus.CANCELLED},
            synchronize_session=False,
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, student: Student) -> Student:
        self.db.refresh(student)
        return self.get_for_school(student.id, student.school_id)
