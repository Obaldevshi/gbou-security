import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock
import pytest

spec = importlib.util.spec_from_file_location('kiosk_device_tests', Path(__file__).parents[1] / 'server.py')
kiosk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kiosk)


def handler(headers, client='127.0.0.1'):
    instance = object.__new__(kiosk.KioskHandler)
    instance.headers = headers
    instance.client_address = (client, 0)
    instance._json = Mock()
    instance._read_json = Mock(side_effect=AssertionError('Must not read body'))
    return instance


@pytest.mark.parametrize('headers,client', [
    ({'Host': 'evil.example:8765'}, '127.0.0.1'),
    ({'Host': '127.0.0.1:8765', 'Origin': 'https://evil.example'}, '127.0.0.1'),
    ({'Host': '127.0.0.1:8765'}, '192.0.2.1'),
])
def test_privileged_bridge_is_loopback_and_same_origin(headers, client):
    instance = handler(headers, client)
    instance._device_control('rebind')
    assert instance._json.call_args.args[0] == 403
    instance._read_json.assert_not_called()


@pytest.mark.parametrize('extra,expected', [
    ({}, 403),
    ({'X-GBOU-Local-Action': 'device-rebind', 'Content-Type': 'text/plain'}, 403),
    ({'X-GBOU-Local-Action': 'device-rebind', 'Content-Type': 'application/json', 'Content-Length': '9000'}, 413),
    ({'X-GBOU-Local-Action': 'device-rebind', 'Content-Type': 'application/json', 'Content-Length': '20', 'Transfer-Encoding': 'chunked'}, 403),
])
def test_simple_forms_chunked_and_large_body_rejected_before_read(extra, expected):
    instance = handler({'Host': '127.0.0.1:8765', **extra})
    instance._device_control('rebind')
    assert instance._json.call_args.args[0] == expected
    instance._read_json.assert_not_called()


def test_valid_request_only_calls_fixed_unix_action(monkeypatch):
    import sys
    bridge = Mock(return_value=(200, {'phase': 'preparing'}))
    monkeypatch.setitem(sys.modules, 'device_control', SimpleNamespace(control_request=bridge))
    headers = {'Host': '127.0.0.1:8765', 'Origin': 'http://127.0.0.1:8765',
               'X-GBOU-Local-Action': 'device-rebind', 'Content-Type': 'application/json', 'Content-Length': '80'}
    instance = handler(headers)
    payload = {'login': 'synthetic', 'password': 'synthetic', 'confirmation': 'ОТВЯЗАТЬ'}
    instance._read_json = Mock(return_value=payload)
    instance._device_control('rebind')
    bridge.assert_called_once_with('rebind', payload)
    assert instance._json.call_args.args == (200, {'phase': 'preparing'})


def test_extra_command_or_path_cannot_reach_root_bridge():
    headers = {'Host': '127.0.0.1:8765', 'X-GBOU-Local-Action': 'device-rebind',
               'Content-Type': 'application/json', 'Content-Length': '80'}
    instance = handler(headers)
    instance._read_json = Mock(return_value={'login': 'a', 'password': 'b', 'confirmation': 'ОТВЯЗАТЬ', 'command': 'anything'})
    instance._device_control('rebind')
    assert instance._json.call_args.args[0] == 422
