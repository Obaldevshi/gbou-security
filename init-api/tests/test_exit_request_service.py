from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.core.exceptions import ConflictError, NotFoundError, UnprocessableEntityError
from app.models.exit_request import ExitReasonType, ExitRequestStatus
from app.schemas.exit_request import ExitRequestCreate
from app.services.exit_request_service import ExitRequestService


class FakeExitRequestRepository:
    def __init__(self):
        self.school_class = SimpleNamespace(id=10, school_id=1, name="5А")
        self.student = SimpleNamespace(id=20, school_id=1, class_id=10)
        self.pending = None
        self.created_values = None
        self.guard_queue = []
        self.release_target = None
        self.commits = 0

    def get_teacher_classes(self, teacher_id, school_id):
        return [self.school_class]

    def get_available_class(self, teacher_id, school_id, class_id):
        if teacher_id == 1 and school_id == 1 and class_id == 10:
            return self.school_class
        return None

    def get_class_students(self, school_id, class_id):
        return [self.student]

    def get_available_student(self, school_id, class_id, student_id):
        if (school_id, class_id, student_id) == (1, 10, 20):
            return self.student
        return None

    def get_pending_for_student(self, student_id):
        return self.pending

    def add(self, values):
        self.created_values = values
        return SimpleNamespace(id=30)

    def commit(self):
        self.commits += 1

    def rollback(self):
        return None

    def load_response_relations(self, request_id):
        return SimpleNamespace(id=request_id)

    def get_pending_for_school(self, school_id):
        return self.guard_queue if school_id == 1 else []

    def get_for_release(self, school_id, request_id):
        if school_id != 1 or self.release_target is None:
            return None
        return self.release_target if self.release_target.id == request_id else None

    def get_for_teacher(self, teacher_id, school_id):
        if teacher_id != 1 or school_id != 1:
            return []
        return self.guard_queue


@pytest.fixture
def teacher():
    return SimpleNamespace(id=1, school_id=1)


@pytest.fixture
def guard():
    return SimpleNamespace(id=2, school_id=1)


def test_create_pending_request_trims_custom_reason(teacher):
    repository = FakeExitRequestRepository()
    service = ExitRequestService(repository)

    result = service.create(
        teacher,
        ExitRequestCreate(
            class_id=10,
            student_id=20,
            reason_type=ExitReasonType.OTHER,
            custom_reason="  Семейные обстоятельства  ",
            scheduled_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        ),
    )

    assert result.id == 30
    assert repository.created_values["custom_reason"] == "Семейные обстоятельства"
    assert repository.created_values["status"] == ExitRequestStatus.PENDING
    assert repository.created_values["school_id"] == teacher.school_id
    assert repository.created_values["teacher_id"] == teacher.id


def test_other_reason_requires_text(teacher):
    service = ExitRequestService(FakeExitRequestRepository())

    with pytest.raises(UnprocessableEntityError) as error:
        service.create(
            teacher,
            ExitRequestCreate(
                class_id=10,
                student_id=20,
                reason_type=ExitReasonType.OTHER,
                custom_reason="  ",
                scheduled_at=datetime.now(timezone.utc) + timedelta(minutes=10),
            ),
        )

    assert error.value.code == "custom_reason_required"


def test_pending_student_request_is_not_duplicated(teacher):
    repository = FakeExitRequestRepository()
    repository.pending = SimpleNamespace(id=99)
    service = ExitRequestService(repository)

    with pytest.raises(ConflictError) as error:
        service.create(
            teacher,
            ExitRequestCreate(
                class_id=10,
                student_id=20,
                reason_type=ExitReasonType.PARENT_NOTE,
                scheduled_at=datetime.now(timezone.utc) + timedelta(minutes=10),
            ),
        )

    assert error.value.code == "active_request_exists"


def test_past_time_is_rejected(teacher):
    service = ExitRequestService(FakeExitRequestRepository())

    with pytest.raises(UnprocessableEntityError) as error:
        service.create(
            teacher,
            ExitRequestCreate(
                class_id=10,
                student_id=20,
                reason_type=ExitReasonType.HEALTH,
                scheduled_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            ),
        )

    assert error.value.code == "scheduled_at_in_past"


def test_guard_queue_is_limited_to_guard_school(guard):
    repository = FakeExitRequestRepository()
    repository.guard_queue = [SimpleNamespace(id=31), SimpleNamespace(id=32)]

    result = ExitRequestService(repository).get_guard_queue(guard)

    assert [request.id for request in result] == [31, 32]


def test_guard_releases_pending_request(guard):
    repository = FakeExitRequestRepository()
    repository.release_target = SimpleNamespace(
        id=31,
        status=ExitRequestStatus.PENDING,
        released_at=None,
        released_by_id=None,
    )

    result = ExitRequestService(repository).release(guard, 31)

    assert result.status == ExitRequestStatus.RELEASED
    assert result.released_by_id == guard.id
    assert result.released_at.tzinfo is not None
    assert repository.commits == 1


def test_guard_cannot_release_processed_request(guard):
    repository = FakeExitRequestRepository()
    repository.release_target = SimpleNamespace(
        id=31,
        status=ExitRequestStatus.RELEASED,
        released_at=datetime.now(timezone.utc),
        released_by_id=2,
    )

    with pytest.raises(ConflictError) as error:
        ExitRequestService(repository).release(guard, 31)

    assert error.value.code == "request_already_processed"
    assert repository.commits == 0


def test_guard_cannot_release_foreign_request(guard):
    with pytest.raises(NotFoundError) as error:
        ExitRequestService(FakeExitRequestRepository()).release(guard, 999)

    assert error.value.code == "request_not_available"


def test_teacher_snapshot_splits_and_sorts_requests(teacher):
    repository = FakeExitRequestRepository()
    now = datetime.now(timezone.utc)
    repository.guard_queue = [
        SimpleNamespace(
            id=31,
            status=ExitRequestStatus.PENDING,
            scheduled_at=now + timedelta(minutes=20),
            created_at=now,
            released_at=None,
        ),
        SimpleNamespace(
            id=32,
            status=ExitRequestStatus.RELEASED,
            scheduled_at=now,
            created_at=now - timedelta(minutes=30),
            released_at=now - timedelta(minutes=1),
        ),
        SimpleNamespace(
            id=33,
            status=ExitRequestStatus.PENDING,
            scheduled_at=now + timedelta(minutes=10),
            created_at=now,
            released_at=None,
        ),
        SimpleNamespace(
            id=34,
            status=ExitRequestStatus.RELEASED,
            scheduled_at=now,
            created_at=now - timedelta(minutes=20),
            released_at=now,
        ),
    ]

    active, history = ExitRequestService(repository).get_teacher_requests(teacher)

    assert [request.id for request in active] == [33, 31]
    assert [request.id for request in history] == [34, 32]
