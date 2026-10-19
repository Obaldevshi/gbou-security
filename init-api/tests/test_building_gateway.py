import importlib.util
import json
from pathlib import Path
import pytest


@pytest.fixture
def gateway(monkeypatch):
    folder = Path(__file__).parents[1] / 'local-node/gateway'
    monkeypatch.syspath_prepend(str(folder))
    spec = importlib.util.spec_from_file_location('building_reconciler', folder / 'reconcile.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def route(building, generation):
    return {'school_id': 2, 'building_id': building, 'generation': generation,
            'hostname': f'2036-{building}.gbousecurity.ru', 'public_key': f'synthetic-public-{building}'}


def test_generations_independent_and_previous_high_floor_not_applied_to_neighbour(gateway, tmp_path):
    previous = {'keys': [], 'generations': {'2': 3}, 'host_generations': {
        '2036-1.gbousecurity.ru': {'school_id': 2, 'building_id': None, 'generation': 3}}}
    manifest = {'routes': [route(1, 3), route(2, 1)]}
    gateway.validate_generations(previous, manifest)
    state = tmp_path / 'state.json'
    gateway.save_managed_state(state, previous, manifest)
    saved = json.loads(state.read_text())
    assert saved['generations']['2:1'] == 3 and saved['generations']['2:2'] == 1
    with pytest.raises(ValueError, match='Stale'):
        gateway.validate_generations(saved, {'routes': [route(1, 2), route(2, 1)]})
    changed = route(1, 4)
    changed['building_id'] = 2
    with pytest.raises(ValueError, match='ownership'):
        gateway.validate_generations(saved, {'routes': [changed]})


def test_old_state_requires_known_legacy_host_or_explicit_existing_pin(gateway):
    previous = {'keys': [], 'generations': {'2': 3}}
    with pytest.raises(ValueError, match='preflight'):
        gateway.validate_generations(previous, {'routes': [route(2, 1)]})
    pins = [{'school_id': 2, 'hostname': '2036-1.gbousecurity.ru'}]
    gateway.validate_generations(previous, {'routes': [route(1, 3), route(2, 1)]}, pins)
    with pytest.raises(ValueError, match='Stale'):
        gateway.validate_generations(previous, {'routes': [route(1, 2)]}, pins)


def test_manifest_v2_refuses_duplicate_building_even_with_different_hosts(gateway):
    import base64
    first = route(1, 1) | {'tunnel_ip': '10.78.0.2', 'public_key': base64.b64encode(b'1' * 32).decode()}
    second = route(2, 1) | {'tunnel_ip': '10.78.0.3', 'public_key': base64.b64encode(b'2' * 32).decode()}
    valid = gateway.validate_routes({'schema_version': 2, 'routes': [first, second]})
    assert '10.78.0.2:443' in gateway.render_haproxy(valid)
    assert '10.78.0.3:443' in gateway.render_haproxy(valid)
    with pytest.raises(ValueError, match='building writer'):
        gateway.validate_routes({'schema_version': 2, 'routes': [first, second | {'building_id': 1}]})


def test_wireguard_render_is_idempotent_without_blank_line_growth(gateway):
    import base64
    key = base64.b64encode(b'1' * 32).decode()
    other = base64.b64encode(b'2' * 32).decode()
    routes = [{'managed': True, 'public_key': key, 'tunnel_ip': '10.78.0.4'}]
    source = '[Interface]\nPrivateKey = SYNTHETIC-NOT-A-KEY\nAddress = 10.77.203.1/24\n\n[Peer]\nPublicKey = ' + other + '\nAllowedIPs = 10.77.203.3/32\n\n[Peer]\nPublicKey = ' + key + '\nAllowedIPs = 10.78.0.4/32\n'
    first = gateway.render_wireguard(source, {key}, routes)
    assert gateway.render_wireguard(first, {key}, routes) == first
    assert 'SYNTHETIC-NOT-A-KEY' in first and other in first
