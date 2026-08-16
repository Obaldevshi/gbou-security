from datetime import datetime

from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import (
    ExitRequest,
    ExitRequestStatus,
    SchoolClass,
    Student,
    TeacherClassAssignment,
)


class ExitRequestRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_teacher_classes(self, teacher_id: int, school_id: int) -> list[SchoolClass]:
        return (
            self.db.query(SchoolClass)
            .join(
                TeacherClassAssignment,
                TeacherClassAssignment.class_id == SchoolClass.id,
            )
            .filter(
                TeacherClassAssignment.teacher_id == teacher_id,
                SchoolClass.school_id == school_id,
                SchoolClass.is_active.is_(True),
            )
            .order_by(SchoolClass.name.asc(), SchoolClass.id.asc())
            .all()
        )

    def get_available_class(
        self,
        teacher_id: int,
        school_id: int,
        class_id: int,
    ) -> SchoolClass | None:
        return (
            self.db.query(SchoolClass)
            .join(
                TeacherClassAssignment,
                TeacherClassAssignment.class_id == SchoolClass.id,
            )
            .filter(
                SchoolClass.id == class_id,
                SchoolClass.school_id == school_id,
                SchoolClass.is_active.is_(True),
                TeacherClassAssignment.teacher_id == teacher_id,
            )
            .first()
        )

    def get_class_students(self, school_id: int, class_id: int) -> list[Student]:
        return (
            self.db.query(Student)
            .filter(
                Student.school_id == school_id,
                Student.class_id == class_id,
                Student.is_active.is_(True),
            )
            .order_by(
                Student.last_name.asc(),
                Student.first_name.asc(),
                Student.middle_name.asc(),
                Student.id.asc(),
            )
            .all()
        )

    def get_teacher_students(self, teacher_id: int, school_id: int) -> list[Student]:
        return (
            self.db.query(Student)
            .options(joinedload(Student.school_class))
            .join(TeacherClassAssignment, TeacherClassAssignment.class_id == Student.class_id)
            .filter(TeacherClassAssignment.teacher_id == teacher_id, Student.school_id == school_id)
            .order_by(Student.last_name.asc(), Student.first_name.asc())
            .all()
        )

    def get_teacher_student(self, teacher_id: int, school_id: int, student_id: int) -> Student | None:
        return (
            self.db.query(Student)
            .options(joinedload(Student.school_class))
            .join(TeacherClassAssignment, TeacherClassAssignment.class_id == Student.class_id)
            .filter(TeacherClassAssignment.teacher_id == teacher_id, Student.school_id == school_id, Student.id == student_id)
            .first()
        )

    def add_student(self, student: Student) -> None:
        self.db.add(student)

    def delete_student_with_requests(self, student: Student) -> None:
        self.db.query(ExitRequest).filter(ExitRequest.student_id == student.id).delete(synchronize_session=False)
        self.db.delete(student)

    def refresh_student(self, student: Student) -> Student:
        self.db.refresh(student)
        return student

    def get_available_student(
        self,
        school_id: int,
        class_id: int,
        student_id: int,
    ) -> Student | None:
        return (
            self.db.query(Student)
            .filter(
                Student.id == student_id,
                Student.school_id == school_id,
                Student.class_id == class_id,
                Student.is_active.is_(True),
            )
            .first()
        )

    def get_pending_for_student(self, student_id: int) -> ExitRequest | None:
        return (
            self.db.query(ExitRequest)
            .filter(
                ExitRequest.student_id == student_id,
                ExitRequest.status == ExitRequestStatus.PENDING,
            )
            .with_for_update()
            .first()
        )

    def add(self, values: dict) -> ExitRequest:
        request = ExitRequest(**values)
        self.db.add(request)
        self.db.flush()
        return request

    def load_response_relations(self, request_id: int) -> ExitRequest:
        return (
            self.db.query(ExitRequest)
            .options(
                joinedload(ExitRequest.school_class),
                joinedload(ExitRequest.student),
                joinedload(ExitRequest.teacher),
            )
            .filter(ExitRequest.id == request_id)
            .one()
        )

    def get_pending_for_school(self, school_id: int) -> list[ExitRequest]:
        return (
            self.db.query(ExitRequest)
            .options(
                joinedload(ExitRequest.school_class),
                joinedload(ExitRequest.student),
                joinedload(ExitRequest.teacher),
            )
            .filter(
                ExitRequest.school_id == school_id,
                ExitRequest.status == ExitRequestStatus.PENDING,
            )
            .order_by(
                ExitRequest.scheduled_at.asc(),
                ExitRequest.created_at.asc(),
                ExitRequest.id.asc(),
            )
            .all()
        )

    def get_for_release(self, school_id: int, request_id: int) -> ExitRequest | None:
        return (
            self.db.query(ExitRequest)
            .filter(
                ExitRequest.id == request_id,
                ExitRequest.school_id == school_id,
            )
            .with_for_update()
            .first()
        )

    def get_for_update(
        self,
        school_id: int,
        request_id: int,
        teacher_id: int | None = None,
    ) -> ExitRequest | None:
        query = self.db.query(ExitRequest).filter(
            ExitRequest.id == request_id,
            ExitRequest.school_id == school_id,
        )
        if teacher_id is not None:
            query = query.filter(ExitRequest.teacher_id == teacher_id)
        return query.with_for_update().first()

    def expire_pending_before(self, school_id: int, cutoff: datetime) -> int:
        return (
            self.db.query(ExitRequest)
            .filter(
                ExitRequest.school_id == school_id,
                ExitRequest.status == ExitRequestStatus.PENDING,
                ExitRequest.scheduled_at < cutoff,
            )
            .update(
                {ExitRequest.status: ExitRequestStatus.EXPIRED},
                synchronize_session=False,
            )
        )

    def get_for_teacher(
        self,
        teacher_id: int,
        school_id: int,
    ) -> list[ExitRequest]:
        return (
            self.db.query(ExitRequest)
            .options(
                joinedload(ExitRequest.school_class),
                joinedload(ExitRequest.student),
                joinedload(ExitRequest.teacher),
            )
            .filter(
                ExitRequest.teacher_id == teacher_id,
                ExitRequest.school_id == school_id,
            )
            .all()
        )

    def get_for_school(self, school_id: int) -> list[ExitRequest]:
        return (
            self.db.query(ExitRequest)
            .options(
                joinedload(ExitRequest.school_class),
                joinedload(ExitRequest.student),
                joinedload(ExitRequest.teacher),
            )
            .filter(ExitRequest.school_id == school_id)
            .all()
        )

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()
