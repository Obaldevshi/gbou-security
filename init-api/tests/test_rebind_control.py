"""Isolated control tests: never contact a real school or call systemctl."""
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import pytest


@pytest.fixture
def control(monkeypatch, tmp_path):
    spec = importlib.util.spec_from_file_location('isolated_rebind', Path(__file__).parents[1] / 'local-node/rebind_control.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, 'STATE', tmp_path)
    monkeypatch.setattr(module, 'MARKER', tmp_path / 'not-present')
    monkeypatch.setattr(module, 'cloud', lambda *a, **k: pytest.fail('Unexpected network request'))
    monkeypatch.setattr(module, 'run', lambda *a: pytest.fail('Unexpected system command'))
    return module


def device(role='terminal'):
    return {'school_id': 2, 'building_id': 1, 'device_id': '11111111-2222-4333-8444-555555555555',
            'hostname': 'school-2.gbousecurity.ru', 'role': role}


def cloud_stub(role='terminal', primary=None, school=2, temporary=False):
    def call(path, body=None, token=None):
        if path == '/login':
            return {'access_token': 'synthetic-admin-jwt', 'password_change_required': temporary}
        assert path == '/schools/2' and token == 'synthetic-admin-jwt'
        return {'overview': {'school_id': school, 'hostname': 'school-2.gbousecurity.ru',
                'primary_device_id': primary,
                'devices': [{**device(role), 'state': 'active'}]}}
    return call


PAYLOAD = {'login': 'Admin', 'password': 'synthetic-password', 'confirmation': 'ОТВЯЗАТЬ'}


def test_own_administrator_can_authorize(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub())
    assert control.authorize(PAYLOAD, device()) == 'synthetic-admin-jwt'


@pytest.mark.parametrize('payload', [{}, {**PAYLOAD, 'confirmation': ''}, {**PAYLOAD, 'password': ''}, {**PAYLOAD, 'login': []}])
def test_confirmation_and_shape_before_network(control, payload):
    with pytest.raises(control.ControlError) as error:
        control.authorize(payload, device())
    assert error.value.status == 422


def test_foreign_school_denied(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub(school=3))
    with pytest.raises(control.ControlError) as error:
        control.authorize(PAYLOAD, device())
    assert error.value.status == 403


def test_other_building_of_same_school_denied(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub())
    with pytest.raises(control.ControlError) as error:
        control.authorize(PAYLOAD, {**device(), 'building_id': 2})
    assert error.value.status == 403


def test_building_registry_checks_only_own_endpoint(control, monkeypatch):
    def call(path, body=None, token=None):
        if path == '/login':
            return {'access_token': 'synthetic-admin-jwt'}
        return {'networking_scope': 'building', 'overview': {}, 'building_overviews': [
            {'school_id': 2, 'building_id': 1, 'hostname': device()['hostname'],
             'primary_device_id': None, 'devices': [{**device(), 'state': 'active'}]},
            {'school_id': 2, 'building_id': 2, 'hostname': '2-2.gbousecurity.ru', 'devices': []}]}
    monkeypatch.setattr(control, 'cloud', call)
    assert control.authorize(PAYLOAD, device()) == 'synthetic-admin-jwt'


def test_role_mismatch_denied(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub(role='primary'))
    with pytest.raises(control.ControlError):
        control.authorize(PAYLOAD, device())


def test_temporary_password_denied(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub(temporary=True))
    with pytest.raises(control.ControlError) as error:
        control.authorize(PAYLOAD, device())
    assert error.value.status == 403


def test_current_primary_must_match_registry(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub(role='primary', primary='another'))
    with pytest.raises(control.ControlError) as error:
        control.authorize(PAYLOAD, device('primary'))
    assert error.value.status == 409


def test_local_attempt_limit_is_bounded_and_has_no_identifiers(control, monkeypatch):
    monkeypatch.setattr(control, 'cloud', cloud_stub())
    for _ in range(5):
        control.authorize(PAYLOAD, device())
    with pytest.raises(control.ControlError) as error:
        control.authorize(PAYLOAD, device())
    assert error.value.status == 429
    assert len(control.ATTEMPTS) == 5 and all(isinstance(t, float) for t in control.ATTEMPTS)


def test_authentication_failure_cannot_create_job_or_run_command(control, monkeypatch):
    monkeypatch.setattr(control, 'load', lambda: None)
    monkeypatch.setattr(control, 'descriptor', device)
    monkeypatch.setattr(control, 'save', lambda *a: pytest.fail('Unauthorized job'))
    def deny(*args, **kwargs):
        raise control.ControlError(401, 'Denied')
    monkeypatch.setattr(control, 'cloud', deny)
    with pytest.raises(Exception):
        control.submit(PAYLOAD)
    assert not control.LOCK.locked()


def test_job_has_no_login_password_admin_token(control, monkeypatch):
    jobs = []
    monkeypatch.setattr(control, 'load', lambda: None)
    monkeypatch.setattr(control, 'descriptor', device)
    monkeypatch.setattr(control, 'authorize', lambda *a: 'synthetic-admin-jwt')
    monkeypatch.setattr(control, 'save', lambda job: jobs.append(dict(job)))
    monkeypatch.setattr(control, 'status', lambda: {'phase': 'preparing'})
    monkeypatch.setattr(control.threading, 'Thread', lambda **k: SimpleNamespace(start=lambda: None))
    assert control.submit(PAYLOAD)['phase'] == 'preparing'
    raw = json.dumps(jobs)
    for secret in ['synthetic-password', 'synthetic-admin-jwt', 'Admin']:
        assert secret not in raw
    assert 'login' not in jobs[0] and 'password' not in jobs[0]


def test_existing_fence_blocks_new_job(control, monkeypatch):
    control.MARKER.write_text('preserved operation')
    monkeypatch.setattr(control, 'load', lambda: None)
    with pytest.raises(control.ControlError) as error:
        control.submit(PAYLOAD)
    assert error.value.status == 409
    assert control.MARKER.read_text() == 'preserved operation'


def test_public_status_cannot_leak_job_secrets(control, monkeypatch):
    job = {'phase': 'ready_for_activation', 'message': 'ready', 'role': 'primary',
           'hostname': '2.gbousecurity.ru', 'password': 'never', 'token': 'never', 'device_id': 'private'}
    monkeypatch.setattr(control, 'load', lambda: job)
    assert set(control.status()) == {'phase', 'message', 'role', 'hostname'}


def test_root_protocol_rejects_oversized_before_dispatch(control):
    handler = object.__new__(control.Handler)
    handler.request = SimpleNamespace(settimeout=lambda _: None)
    handler.rfile, handler.wfile = io.BytesIO(b'x' * 8193), io.BytesIO()
    handler.handle()
    assert json.loads(handler.wfile.getvalue())['status'] == 413


def test_unknown_socket_action_is_denied(control):
    handler = object.__new__(control.Handler)
    handler.request = SimpleNamespace(settimeout=lambda _: None)
    handler.rfile, handler.wfile = io.BytesIO(b'{"action":"shell","command":"anything"}\n'), io.BytesIO()
    handler.handle()
    assert json.loads(handler.wfile.getvalue())['status'] == 404
