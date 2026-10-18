from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from app.config.settings import settings
from app.core.exceptions import BaseError
from app.models.user import UserRole
from app.services.auth_service import AuthService
from app.services.exit_request_service import ExitRequestService


@pytest.mark.parametrize('role', [UserRole.TEACHER, UserRole.GUARD, UserRole.SCHOOL_ADMIN])
def test_frozen_school_access_fails_before_read_side_effects(monkeypatch, role):
    monkeypatch.setattr(settings, 'deployment_mode', 'legacy')
    monkeypatch.setattr(settings, 'migration_freeze_writes', True)
    with pytest.raises(BaseError) as result:
        AuthService.ensure_user_can_access(SimpleNamespace(role=role))
    assert result.value.status_code == 503
    assert result.value.code == 'school_migration_freeze'
    assert result.value.headers['Retry-After'] == '300'


def test_frozen_queue_reads_do_not_advance_statuses(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'legacy')
    monkeypatch.setattr(settings, 'migration_freeze_writes', True)
    repository = Mock()
    ExitRequestService(repository)._expire_overdue(2)
    repository.expire_pending_before.assert_not_called()
    repository.commit.assert_not_called()


def test_local_expiry_is_not_disabled_by_cloud_freeze(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'local')
    monkeypatch.setattr(settings, 'migration_freeze_writes', True)
    repository = Mock()
    repository.expire_pending_before.return_value = 1
    ExitRequestService(repository)._expire_overdue(2)
    repository.expire_pending_before.assert_called_once()
    repository.commit.assert_called_once()


def test_school_audit_is_not_written_during_freeze(monkeypatch):
    from starlette.requests import Request
    from app.core import middleware
    monkeypatch.setattr(settings, 'deployment_mode', 'legacy')
    monkeypatch.setattr(settings, 'migration_freeze_writes', True)
    db = Mock()
    db.query.return_value.filter.return_value.first.return_value = SimpleNamespace(school_id=2)
    monkeypatch.setattr(middleware, 'SessionLocal', lambda: db)
    monkeypatch.setattr(middleware, 'verify_token', lambda _: 1)
    request = Request({'type': 'http', 'method': 'POST', 'path': '/api/v1/teacher/exit-requests',
                       'headers': [(b'authorization', b'Bearer test-token')]})
    middleware.RequestLoggingMiddleware._write_audit(request, 503)
    db.add.assert_not_called()
    db.commit.assert_not_called()
    db.close.assert_called_once()


def test_trusted_session_mutations_are_frozen_before_authentication(monkeypatch):
    from fastapi.testclient import TestClient
    from app.main import app
    monkeypatch.setattr(settings, 'deployment_mode', 'legacy')
    monkeypatch.setattr(settings, 'migration_freeze_writes', True)
    with TestClient(app) as client:
        for path in ('/trusted-devices', '/trusted-devices/refresh', '/trusted-devices/revoke-token'):
            response = client.post('/api/v1/auth' + path, json={})
            assert response.status_code == 503
            assert response.json()['code'] == 'school_migration_freeze'
            assert response.headers['Retry-After'] == '300'
