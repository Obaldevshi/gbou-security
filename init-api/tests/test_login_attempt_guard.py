import pytest

from app.core.exceptions import BaseError
from app.services.login_attempt_guard import LoginAttemptGuard


def fail(guard, login):
    with pytest.raises(ValueError):
        with guard.attempt(login):
            raise ValueError('bad password')


def test_one_login_does_not_block_another_on_the_same_network():
    guard = LoginAttemptGuard(attempts=2)
    fail(guard, 'teacher-a')
    fail(guard, ' TEACHER-A ')
    with pytest.raises(BaseError) as result:
        with guard.attempt('teacher-a'):
            pytest.fail('Limited account must not be checked')
    assert result.value.status_code == 429
    assert int(result.value.headers['Retry-After']) > 0
    with guard.attempt('teacher-b'):
        pass


def test_expired_attempts_do_not_require_a_browser_reload():
    clock = [100.0]
    guard = LoginAttemptGuard(attempts=1, window_seconds=60, clock=lambda: clock[0])
    fail(guard, 'teacher')
    clock[0] += 60
    with guard.attempt('teacher'):
        pass


def test_success_clears_only_that_logins_counter():
    guard = LoginAttemptGuard(attempts=2)
    fail(guard, 'teacher-a')
    fail(guard, 'teacher-b')
    with guard.attempt('teacher-a'):
        pass
    fail(guard, 'teacher-a')
    fail(guard, 'teacher-b')
    with pytest.raises(BaseError):
        with guard.attempt('teacher-b'):
            pass
    with guard.attempt('teacher-a'):
        pass


def test_concurrency_limit_is_short_busy_response_not_an_ip_ban():
    guard = LoginAttemptGuard(concurrent=1)
    with guard.attempt('teacher-a'):
        with pytest.raises(BaseError) as result:
            with guard.attempt('teacher-b'):
                pass
        assert result.value.status_code == 503
        assert result.value.headers['Retry-After'] == '2'
    with guard.attempt('teacher-b'):
        pass


def test_memory_bound_and_release_after_exceptions():
    guard = LoginAttemptGuard(capacity=3)
    for index in range(100):
        fail(guard, f'teacher-{index}')
    assert len(guard._buckets) == 3
    assert guard._active == 0


def test_http_retry_after_and_isolation(monkeypatch):
    from types import SimpleNamespace
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.v1.auth import router
    from app.config.settings import settings
    from app.core.dependencies import get_auth_service
    from app.main import base_error_handler
    from app.services import auth_service
    monkeypatch.setattr(settings, 'deployment_mode', 'local')
    monkeypatch.setattr(auth_service, 'school_login_guard', LoginAttemptGuard(attempts=2))
    service = auth_service.AuthService(SimpleNamespace(get_by_login=lambda _: None), None)
    application = FastAPI()
    application.include_router(router, prefix='/api/v1/auth')
    application.add_exception_handler(BaseError, base_error_handler)
    application.dependency_overrides[get_auth_service] = lambda: service
    with TestClient(application) as client:
        for _ in range(2):
            assert client.post('/api/v1/auth/login', json={
                'login': 'teacher-a', 'password': 'wrong-password',
            }).status_code == 401
        result = client.post('/api/v1/auth/login', json={
            'login': 'teacher-a', 'password': 'wrong-password',
        })
        assert result.status_code == 429
        assert result.json()['code'] == 'login_retry_later'
        assert int(result.headers['retry-after']) > 0
        assert client.post('/api/v1/auth/login', json={
            'login': 'teacher-b', 'password': 'wrong-password',
        }).status_code == 401


def test_oversized_bcrypt_login_is_rejected_without_server_error():
    import bcrypt
    from app.core.security import verify_password
    hashed = bcrypt.hashpw(b'correct-password', bcrypt.gensalt(rounds=4)).decode()
    assert verify_password('correct-password', hashed)
    assert not verify_password('x' * 1000, hashed)
    assert not verify_password('wrong-password', 'invalid-hash')
