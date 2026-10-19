"""No hardware: root files and HTTP transport are redirected into tmp dirs."""
import importlib.util
import json
from pathlib import Path
import uuid
import pytest


@pytest.fixture
def agent(monkeypatch, tmp_path):
    folder = Path(__file__).parents[1] / 'local-node'
    monkeypatch.syspath_prepend(str(folder))
    spec = importlib.util.spec_from_file_location('pairing_agent_test', folder / 'pairing_agent.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    root = tmp_path / 'private'
    root.mkdir()
    monkeypatch.setattr(module, 'ROOT', root)
    return module


def test_terminal_enrollment_private_idempotent_no_database(agent):
    from device_enroll import save_enrollment
    device = str(uuid.uuid4())
    data = {'device_id': device, 'role': 'terminal', 'state': 'active', 'school_id': 1,
            'hostname': '236.gbousecurity.ru', 'token': 'a' * 64, 'tunnel_ip': None,
            'gateway_public_key': None, 'gateway_endpoint': None, 'gateway_tunnel_ip': None, 'building_id': 1}
    save_enrollment(dict(data), device, agent.ROOT, agent.CLOUD, 'terminal')
    save_enrollment(dict(data), device, agent.ROOT, agent.CLOUD, 'terminal')
    saved = json.loads((agent.ROOT / 'device.json').read_text())
    assert 'token' not in saved and saved['building_id'] == 1
    assert not (agent.ROOT / 'gbou-wg.conf').exists()
    assert not list(agent.ROOT.glob('*.sqlite*'))
    with pytest.raises(ValueError):
        save_enrollment({**data, 'token': 'b' * 64}, device, agent.ROOT, agent.CLOUD, 'terminal')


def test_state_updates_stay_private(agent):
    agent.state_write({'device_id': 'test', 'poll_token': 'private-test-only'})
    agent.state_write({'device_id': 'test', 'poll_token': 'rotated-test-only'})
    assert json.loads((agent.ROOT / 'pairing-state.json').read_text())['poll_token'] == 'rotated-test-only'
    assert not (agent.ROOT / 'pairing-state.tmp').exists()
    assert 'poll_token' not in agent.VIEW


def test_saved_registration_ack_resumes_without_redelivery(agent, monkeypatch):
    device = str(uuid.uuid4())
    state = {'device_id': device, 'request_id': str(uuid.uuid4()), 'poll_token': 'p' * 64}
    agent.state_write(state)
    (agent.ROOT / 'device.json').write_text(json.dumps({'device_id': device, 'role': 'terminal', 'hostname': '236.gbousecurity.ru'}))
    monkeypatch.setattr(agent, 'identity', lambda: (device, 'unused-public'))
    calls = []
    monkeypatch.setattr(agent, 'api', lambda path, **kwargs: calls.append(path) or {'state': 'completed'})
    agent.worker()
    assert calls == ['/' + state['request_id'] + '/complete']
    assert json.loads((agent.ROOT / 'pairing-state.json').read_text())['completed']
    assert agent.VIEW['qr'] == '' and agent.VIEW['code'] == ''


def test_fresh_worker_posts_to_pairing_root_then_shows_qr(agent, monkeypatch):
    device, request = str(uuid.uuid4()), str(uuid.uuid4())
    monkeypatch.setattr(agent, 'identity', lambda: (device, 'public-test-key'))
    calls, shown = [], []

    def transport(path, body=None, token=None):
        calls.append((path, body is not None, token is not None))
        if path == '':
            assert body['device_id'] == device
            assert len(body['poll_token']) >= 40
            return {'request_id': request, 'qr_url': 'https://gbousecurity.ru/#/connect/' + request,
                    'verification_code': '123456'}
        assert path == '/' + request + '/poll'
        return {'state': 'waiting'}

    class StopAfterFirstPoll(Exception):
        pass

    monkeypatch.setattr(agent, 'api', transport)
    monkeypatch.setattr(agent, 'show_request', lambda state: shown.append(state['request_id']))
    monkeypatch.setattr(agent.time, 'sleep', lambda _: (_ for _ in ()).throw(StopAfterFirstPoll()))
    with pytest.raises(StopAfterFirstPoll):
        agent.worker()
    assert calls == [('', True, False), ('/' + request + '/poll', False, True)]
    assert shown == [request]
    assert json.loads((agent.ROOT / 'pairing-state.json').read_text())['request_id'] == request


def test_loopback_screen_and_state_never_expose_file_proofs(agent):
    from io import BytesIO
    agent.state_write({'poll_token': 'private-test-only'})
    for path in ('/', '/state'):
        handler = object.__new__(agent.Handler)
        handler.headers, handler.path = {'Host': '127.0.0.1:8766'}, path
        handler.wfile = BytesIO()
        handler.send_response = lambda *_: None
        handler.send_header = lambda *_: None
        handler.end_headers = lambda: None
        handler.do_GET()
        assert b'private-test-only' not in handler.wfile.getvalue()
        errors = []
        handler.headers = {'Host': 'attacker.example'}
        handler.send_error = lambda code: errors.append(code)
        handler.do_GET()
        assert errors == [403]


def test_qr_screen_has_small_landscape_grid_and_wrapping_url(agent):
    from io import BytesIO
    agent.update(qr='synthetic-image', code='123456', url='https://gbousecurity.ru/#/connect/test')
    handler = object.__new__(agent.Handler)
    handler.headers, handler.path = {'Host': '127.0.0.1:8766'}, '/'
    handler.wfile = BytesIO()
    handler.send_response = lambda *_: None
    handler.send_header = lambda *_: None
    handler.end_headers = lambda: None
    handler.do_GET()
    page = handler.wfile.getvalue().decode()
    assert 'width="224" height="224"' in page
    assert 'class="pairing-grid"' in page and 'class="pairing-details"' in page
    assert 'overflow-wrap:anywhere' in page
    assert 'width="280"' not in page


def test_child_finisher_skips_primary_and_runs_once(agent, monkeypatch):
    folder = Path(__file__).parents[1] / 'local-node'
    spec = importlib.util.spec_from_file_location('finish_terminal_test', folder / 'finish_terminal.py')
    finish = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(finish)
    monkeypatch.setattr(finish, 'ROOT', agent.ROOT)
    calls = []
    monkeypatch.setattr(finish, 'configure', lambda: calls.append('configured'))
    document = agent.ROOT / 'device.json'
    document.write_text(json.dumps({'role': 'primary', 'device_id': 'test'}))
    finish.main()
    assert calls == []
    document.write_text(json.dumps({'role': 'terminal', 'device_id': 'test'}))
    finish.main()
    finish.main()
    assert calls == ['configured']
