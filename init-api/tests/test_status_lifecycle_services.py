from types import SimpleNamespace

from app.schemas.school import SchoolStatusUpdate
from app.services.school_class_admin_service import SchoolClassAdminService
from app.services.school_service import SchoolService


class FakeStatusRepository:
    def __init__(self, item):
        self.item = item
        self.cancelled = []
        self.commits = 0

    def get_by_id(self, item_id):
        return self.item if self.item.id == item_id else None

    def get_for_school(self, item_id, school_id):
        if self.item.id == item_id and self.item.school_id == school_id:
            return self.item
        return None

    def cancel_pending_requests(self, item_id):
        self.cancelled.append(item_id)

    def commit(self):
        self.commits += 1

    def rollback(self):
        pass

    def refresh(self, item):
        return item


def test_disabling_school_cancels_its_pending_requests():
    repository = FakeStatusRepository(SimpleNamespace(id=1, is_active=True))

    school = SchoolService(repository).set_school_status(
        1,
        SchoolStatusUpdate(is_active=False),
    )

    assert school.is_active is False
    assert repository.cancelled == [1]
    assert repository.commits == 1


def test_disabling_class_cancels_its_pending_requests():
    repository = FakeStatusRepository(
        SimpleNamespace(id=10, school_id=1, is_active=True)
    )

    school_class = SchoolClassAdminService(repository).set_status(1, 10, False)

    assert school_class.is_active is False
    assert repository.cancelled == [10]
    assert repository.commits == 1
