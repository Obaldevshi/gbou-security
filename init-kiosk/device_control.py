"""Narrow root-Unix bridge; never execute system commands in the HTTP handler."""
import json
import socket

SOCKET = '/run/gbou-device-rebind/control.sock'


def control_request(action, payload=None):
    raw = json.dumps({'action': action, 'payload': payload}).encode() + b'\n'
    if len(raw) > 8192:
        return 413, {'message': 'Слишком большой запрос.'}
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(65 if action == 'rebind' else 5)
            client.connect(SOCKET)
            client.sendall(raw)
            with client.makefile('rb') as reader:
                reply = reader.readline(524289)
            if len(reply) > 524288:
                raise ValueError('Oversized control reply')
            result = json.loads(reply)
            assert result['status'] in {200, 401, 403, 404, 409, 413, 422, 429, 503}
            assert isinstance(result['data'], dict)
            return result['status'], result['data']
    except (OSError, ValueError, KeyError, AssertionError):
        return 503, {'message': 'Управление привязкой пока не установлено. Обратитесь к администратору проекта; не удаляйте файлы Raspberry вручную.'}
