import importlib
from datetime import datetime
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config.settings import settings
from app.core.dependencies import get_current_user
from app.core.exceptions import ForbiddenError
from app.models.user import UserRole
from app.services.auth_service import AuthService


@pytest.mark.parametrize('mode,expected,absent', [
    ('cloud', '/api/v1/system/schools', '/api/v1/teacher/classes'),
    ('local', '/api/v1/school/classes', '/api/v1/system/schools'),
    ('legacy', '/api/v1/system/schools', '/nonexistent'),
])
def test_route_boundaries_keep_profile_and_password_change(monkeypatch, mode, expected, absent):
    from app.api.v1 import router
    monkeypatch.setattr(settings, 'deployment_mode', mode)
    importlib.reload(router)
    try:
        app = FastAPI()
        app.include_router(router.api_router)
        paths = set(app.openapi()['paths'])
        assert expected in paths
        assert absent not in paths
        assert '/api/v1/users/' in paths
        assert '/api/v1/users/change-password' in paths
    finally:
        monkeypatch.setattr(settings, 'deployment_mode', 'legacy')
        importlib.reload(router)


@pytest.mark.parametrize('mode,role,allowed', [
    ('cloud', UserRole.SUPER_ADMIN, True),
    ('cloud', UserRole.SCHOOL_ADMIN, False),
    ('cloud', UserRole.TEACHER, False),
    ('cloud', UserRole.GUARD, False),
    ('local', UserRole.SUPER_ADMIN, False),
    ('local', UserRole.SCHOOL_ADMIN, True),
    ('local', UserRole.TEACHER, True),
    ('local', UserRole.GUARD, True),
])
def test_role_boundaries(monkeypatch, mode, role, allowed):
    monkeypatch.setattr(settings, 'deployment_mode', mode)
    user = SimpleNamespace(role=role, is_active=True, school_id=1,
                           school=SimpleNamespace(is_active=True), building=SimpleNamespace(is_active=True))
    if allowed:
        AuthService.ensure_user_can_access(user)
    else:
        with pytest.raises(ForbiddenError):
            AuthService.ensure_user_can_access(user)


def test_cloud_events_deny_access_before_querying_database(monkeypatch):
    from app.api.v1.user import request_events
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    with pytest.raises(ForbiddenError):
        request_events(SimpleNamespace(must_change_password=False))


def test_cloud_school_login_hint_does_not_advertise_removed_connection_menu(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    with pytest.raises(ForbiddenError) as error:
        AuthService.ensure_user_can_access(SimpleNamespace(role=UserRole.TEACHER))
    assert error.value.code == 'local_access_required'
    assert 'Вход в школу' in error.value.message
    assert 'Подключение к школе' not in error.value.message


def test_cloud_profile_remains_available(monkeypatch):
    from app.api.v1.user import router
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    user = SimpleNamespace(id=1, login='chief', full_name='Главный администратор', phone=None,
                           role=UserRole.SUPER_ADMIN, school_id=None, building_id=None,
                           building_name=None, is_active=True, must_change_password=False,
                           created_at=datetime.now(), updated_at=datetime.now())
    app = FastAPI()
    app.include_router(router, prefix='/api/v1/users')
    app.dependency_overrides[get_current_user] = lambda: user
    with TestClient(app) as client:
        result = client.get('/api/v1/users/')
    assert result.status_code == 200
    assert result.json()['data']['login'] == 'chief'
    assert 'hashed_password' not in result.json()['data']
