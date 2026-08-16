from datetime import datetime, timedelta, timezone

from app.constants.messages import ExitRequestMessages
from app.core.exceptions import ConflictError, NotFoundError, UnprocessableEntityError
from app.models.exit_request import ExitReasonType, ExitRequestStatus, Student
from app.models.user import User
from app.repositories.exit_request_repository import ExitRequestRepository
from app.schemas.exit_request import ExitRequestCreate
from app.schemas.student_admin import StudentCreate


class ExitRequestService:
    EXPIRATION_GRACE = timedelta(minutes=15)

    def __init__(self, repository: ExitRequestRepository):
        self.repository = repository

    def get_teacher_classes(self, teacher: User):
        return self.repository.get_teacher_classes(teacher.id, teacher.school_id)

    def get_class_students(self, teacher: User, class_id: int):
        self._require_available_class(teacher, class_id)
        return self.repository.get_class_students(teacher.school_id, class_id)

    def get_teacher_students(self, teacher: User):
        return self.repository.get_teacher_students(teacher.id, teacher.school_id)

    def create_teacher_student(self, teacher: User, data: StudentCreate):
        self._require_available_class(teacher, data.class_id)
        student = Student(school_id=teacher.school_id, is_active=True, **data.model_dump())
        try:
            self.repository.add_student(student)
            self.repository.commit()
            return self.repository.refresh_student(student)
        except Exception:
            self.repository.rollback()
            raise

    def set_teacher_student_status(self, teacher: User, student_id: int, active: bool):
        student = self._teacher_student(teacher, student_id)
        student.is_active = active
        if not active:
            self.repository.cancel_pending_for_student(student.id)
        try:
            self.repository.commit()
            return self.repository.refresh_student(student)
        except Exception:
            self.repository.rollback()
            raise

    def delete_teacher_student(self, teacher: User, student_id: int) -> None:
        student = self._teacher_student(teacher, student_id)
        try:
            self.repository.delete_student_with_requests(student)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _teacher_student(self, teacher: User, student_id: int):
        student = self.repository.get_teacher_student(teacher.id, teacher.school_id, student_id)
        if student is None:
            raise NotFoundError("Ученик недоступен", code="student_not_available")
        return student

    def create(self, teacher: User, data: ExitRequestCreate):
        self._require_available_class(teacher, data.class_id)
        student = self.repository.get_available_student(
            teacher.school_id,
            data.class_id,
            data.student_id,
        )
        if student is None:
            raise NotFoundError(
                ExitRequestMessages.STUDENT_NOT_AVAILABLE.value,
                code="student_not_available",
            )

        custom_reason = self._validate_reason(data.reason_type, data.custom_reason)
        scheduled_at = self._normalize_scheduled_at(data.scheduled_at)

        if self.repository.get_pending_for_student(student.id) is not None:
            raise ConflictError(
                ExitRequestMessages.ACTIVE_REQUEST_EXISTS.value,
                code="active_request_exists",
            )

        try:
            request = self.repository.add(
                {
                    "school_id": teacher.school_id,
                    "class_id": data.class_id,
                    "student_id": student.id,
                    "teacher_id": teacher.id,
                    "reason_type": data.reason_type,
                    "custom_reason": custom_reason,
                    "scheduled_at": scheduled_at,
                    "status": ExitRequestStatus.PENDING,
                }
            )
            request_id = request.id
            self.repository.commit()
            return self.repository.load_response_relations(request_id)
        except Exception:
            self.repository.rollback()
            raise

    def get_guard_queue(self, guard: User):
        self._expire_overdue(guard.school_id)
        return self.repository.get_pending_for_school(guard.school_id)

    def get_teacher_requests(self, teacher: User):
        self._expire_overdue(teacher.school_id)
        requests = self.repository.get_for_teacher(teacher.id, teacher.school_id)
        active = sorted(
            (
                request
                for request in requests
                if request.status == ExitRequestStatus.PENDING
            ),
            key=lambda request: (
                request.scheduled_at,
                request.created_at,
                request.id,
            ),
        )
        history = sorted(
            (
                request
                for request in requests
                if request.status != ExitRequestStatus.PENDING
            ),
            key=lambda request: (
                request.released_at or request.scheduled_at or request.created_at,
                request.id,
            ),
            reverse=True,
        )
        return active, history

    def get_school_requests(self, school_id: int):
        self._expire_overdue(school_id)
        requests = self.repository.get_for_school(school_id)
        active = sorted(
            (item for item in requests if item.status == ExitRequestStatus.PENDING),
            key=lambda item: (item.scheduled_at, item.created_at, item.id),
        )
        history = sorted(
            (item for item in requests if item.status != ExitRequestStatus.PENDING),
            key=lambda item: (item.released_at or item.created_at, item.id),
            reverse=True,
        )
        return active, history

    def release(self, guard: User, request_id: int):
        request = self.repository.get_for_release(guard.school_id, request_id)
        if request is None:
            raise NotFoundError(
                ExitRequestMessages.REQUEST_NOT_AVAILABLE.value,
                code="request_not_available",
            )
        if request.status != ExitRequestStatus.PENDING:
            raise ConflictError(
                ExitRequestMessages.REQUEST_ALREADY_PROCESSED.value,
                code="request_already_processed",
            )

        try:
            request.status = ExitRequestStatus.RELEASED
            request.released_at = datetime.now(timezone.utc)
            request.released_by_id = guard.id
            self.repository.commit()
            return request
        except Exception:
            self.repository.rollback()
            raise

    def cancel_by_teacher(self, teacher: User, request_id: int):
        return self._cancel(teacher.school_id, request_id, teacher_id=teacher.id)

    def cancel_by_school_admin(self, school_admin: User, request_id: int):
        return self._cancel(school_admin.school_id, request_id)

    def _cancel(
        self,
        school_id: int,
        request_id: int,
        teacher_id: int | None = None,
    ):
        request = self.repository.get_for_update(school_id, request_id, teacher_id)
        if request is None:
            raise NotFoundError(
                ExitRequestMessages.REQUEST_NOT_AVAILABLE.value,
                code="request_not_available",
            )
        if request.status != ExitRequestStatus.PENDING:
            raise ConflictError(
                ExitRequestMessages.REQUEST_ALREADY_PROCESSED.value,
                code="request_already_processed",
            )
        try:
            request.status = ExitRequestStatus.CANCELLED
            self.repository.commit()
            return request
        except Exception:
            self.repository.rollback()
            raise

    def _expire_overdue(self, school_id: int) -> None:
        cutoff = datetime.now(timezone.utc) - self.EXPIRATION_GRACE
        try:
            if self.repository.expire_pending_before(school_id, cutoff):
                self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _require_available_class(self, teacher: User, class_id: int):
        school_class = self.repository.get_available_class(
            teacher.id,
            teacher.school_id,
            class_id,
        )
        if school_class is None:
            raise NotFoundError(
                ExitRequestMessages.CLASS_NOT_AVAILABLE.value,
                code="class_not_available",
            )
        return school_class

    @staticmethod
    def _validate_reason(
        reason_type: ExitReasonType,
        custom_reason: str | None,
    ) -> str | None:
        normalized = custom_reason.strip() if custom_reason else None
        if reason_type == ExitReasonType.OTHER:
            if normalized is None or len(normalized) < 3:
                raise UnprocessableEntityError(
                    ExitRequestMessages.CUSTOM_REASON_REQUIRED.value,
                    code="custom_reason_required",
                )
            return normalized
        if normalized:
            raise UnprocessableEntityError(
                ExitRequestMessages.CUSTOM_REASON_NOT_ALLOWED.value,
                code="custom_reason_not_allowed",
            )
        return None

    @staticmethod
    def _normalize_scheduled_at(value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise UnprocessableEntityError(
                ExitRequestMessages.TIMEZONE_REQUIRED.value,
                code="scheduled_at_timezone_required",
            )
        normalized = value.astimezone(timezone.utc)
        if normalized < datetime.now(timezone.utc) - timedelta(minutes=1):
            raise UnprocessableEntityError(
                ExitRequestMessages.SCHEDULED_AT_IN_PAST.value,
                code="scheduled_at_in_past",
            )
        return normalized
