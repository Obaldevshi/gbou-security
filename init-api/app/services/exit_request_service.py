from datetime import datetime, timedelta, timezone

from app.constants.messages import ExitRequestMessages
from app.core.exceptions import ConflictError, NotFoundError, UnprocessableEntityError
from app.models.exit_request import ExitReasonType, ExitRequestStatus
from app.models.user import User
from app.repositories.exit_request_repository import ExitRequestRepository
from app.schemas.exit_request import ExitRequestCreate


class ExitRequestService:
    def __init__(self, repository: ExitRequestRepository):
        self.repository = repository

    def get_teacher_classes(self, teacher: User):
        return self.repository.get_teacher_classes(teacher.id, teacher.school_id)

    def get_class_students(self, teacher: User, class_id: int):
        self._require_available_class(teacher, class_id)
        return self.repository.get_class_students(teacher.school_id, class_id)

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
        return self.repository.get_pending_for_school(guard.school_id)

    def get_teacher_requests(self, teacher: User):
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
                if request.status == ExitRequestStatus.RELEASED
            ),
            key=lambda request: (request.released_at, request.id),
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
