#!/usr/bin/env python3
"""Fresh-device loopback QR setup. Never starts an API, tunnel or database.

Only the public request ID/code reach the screen. Poll/device/WG secrets stay
in root-only files. Admin approval authorizes registration, NOT writer cutover.
"""
import base64
import html
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, build_opener, ProxyHandler
from device_enroll import NoRedirect, private_write, save_enrollment

ROOT = Path('/etc/gbou-device')
CLOUD = 'https://obaldevshi-gbou-security-ac8a.twc1.net'
PORT = 8766
OPENER = build_opener(ProxyHandler({}), NoRedirect())
LOCK = threading.Lock()
VIEW = {'message': 'Подготовка подключения…', 'qr': '', 'code': '', 'url': ''}


def update(**values):
    with LOCK:
        VIEW.update(values)


def api(path, body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['X-Pairing-Token'] = token
    request = Request(CLOUD + '/api/v1/devices/pairings' + path,
                      data=json.dumps(body or {}).encode(), headers=headers)
    with OPENER.open(request, timeout=20) as response:
        raw = response.read(65537)
        if len(raw) > 65536:
            raise ValueError('Oversized reply')
        return json.loads(raw)


def state_write(data):
    candidate = ROOT / 'pairing-state.tmp'
    # Directory is root0700; recover an interrupted write, not school data.
    if candidate.exists():
        candidate.unlink()
    private_write(candidate, json.dumps(data) + '\n')
    os.replace(candidate, ROOT / 'pairing-state.json')
    if os.name == 'posix':
        descriptor = os.open(ROOT, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def fresh_guard():
    if Path('/var/lib/gbou-local/school.sqlite3').exists() or Path('/etc/wireguard/gbou-wg.conf').exists():
        raise ValueError('Already configured school server')
    if ROOT.is_symlink():
        raise ValueError('Private directory cannot be a symlink')
    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    ROOT.chmod(0o700)
    if (ROOT / 'device.json').exists() and not (ROOT / 'pairing-state.json').exists():
        raise ValueError('Existing non-QR registration must not be replaced')


def identity():
    path = ROOT / 'identity'
    if not path.exists():
        private_write(path, str(uuid.uuid4()))
    device = str(uuid.UUID(path.read_text().strip()))
    key = ROOT / 'wireguard.key'
    if not key.exists():
        private_write(key, subprocess.check_output(['wg', 'genkey'], text=True).strip() + '\n')
    public = subprocess.check_output(['wg', 'pubkey'], input=key.read_text(), text=True).strip()
    return device, public


def show_request(data):
    request = str(uuid.UUID(data['request_id']))
    expected = 'https://gbousecurity.ru/#/connect/' + request
    if data['qr_url'] != expected or not re.fullmatch(r'[0-9]{6}', data['verification_code']):
        raise ValueError('Unexpected pairing reply')
    # Fetch only a public SVG from the fixed central origin, no private header.
    with OPENER.open(CLOUD + '/api/v1/devices/pairings/' + request + '/qr.svg', timeout=20) as response:
        svg = response.read(262145)
        if len(svg) > 262144:
            raise ValueError('Oversized QR')
    update(qr=base64.b64encode(svg).decode(), code=data['verification_code'], url=expected,
           message='Откройте камеру телефона, отсканируйте QR и войдите как администратор. Введите код ниже.')


def registered_message(data):
    if data['role'] == 'terminal':
        if (ROOT / 'terminal-configured.json').exists():
            return 'Дочерний киоск подключён к https://' + data['hostname'] + '. Вернитесь к киоску и войдите как охранник.'
        return ('Дочернее устройство зарегистрировано. Адрес школы: https://' + data['hostname'] +
                '. Установленный киоск подключится автоматически, когда школьный сервер станет доступен. Затем войдите как охранник.')
    return ('Главное устройство зарегистрировано и ожидает подготовки. Адрес школы: https://' + data['hostname'] +
            '. База и сеть НЕ запущены. Подготовьте локальный API, восстановление USB-копии и остановите прежний сервер перед активацией.')


def worker():
    device, public = identity()
    path = ROOT / 'pairing-state.json'
    state = json.loads(path.read_text()) if path.exists() else {}
    if state and state['device_id'] != device:
        raise ValueError('Conflicting saved pairing identity')
    while True:
        try:
            saved = ROOT / 'device.json'
            if saved.exists():
                data = json.loads(saved.read_text())
                if data['device_id'] != device or not state.get('request_id'):
                    raise ValueError('Conflicting saved enrollment')
                update(qr='', code='', url='', message=registered_message(data))
                # Lost ACK is retried, but credentials are never fetched again.
                if not state.get('completed'):
                    api('/' + state['request_id'] + '/complete', token=state['poll_token'])
                    state['completed'] = True
                    state_write(state)
                return
            if not state:
                state = {'device_id': device, 'poll_token': secrets.token_urlsafe(48)}
                state_write(state)
            if not state.get('request_id'):
                data = api('', body={'device_id': device, 'label': 'Raspberry ' + device[:8],
                                 'public_key': public, 'poll_token': state['poll_token']})
                state.update(data)
                state_write(state)
            data = api('/' + state['request_id'] + '/poll', token=state['poll_token'])
            if data['state'] == 'approved':
                enrollment = data['enrollment']
                save_enrollment(enrollment, device, ROOT, CLOUD, enrollment['role'])
                continue
            if data['state'] != 'waiting':
                raise ValueError('Registration completed without local credentials')
            if not VIEW['qr']:
                show_request(state)
            time.sleep(3)
        except HTTPError as error:
            # A delivered enrollment can outlive its ACK TTL. Keep saved files.
            if (ROOT / 'device.json').exists():
                update(message=registered_message(json.loads((ROOT / 'device.json').read_text())))
                return
            if error.code == 404 and state.get('request_id'):
                # Expired/blocked request: rotate proof and QR; never identity.
                state = {}
                update(qr='', code='', url='', message='Обновление QR-кода…')
            else:
                update(message='Подключение пока недоступно (HTTP ' + str(error.code) + '). Повтор через 15 секунд.')
            time.sleep(15)
        except (OSError, ValueError, KeyError, TypeError):
            # Do not log HTTP bodies, tokens, private keys or local filenames.
            update(message='Нет связи или настройки требуют проверки. Файлы сохранены; повтор через 15 секунд.')
            time.sleep(15)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.headers.get('Host') not in {f'127.0.0.1:{PORT}', f'localhost:{PORT}'}:
            self.send_error(403)
            return
        with LOCK:
            view = dict(VIEW)
        if (ROOT / 'terminal-configured.json').exists() and (ROOT / 'device.json').exists():
            view['message'] = registered_message(json.loads((ROOT / 'device.json').read_text()))
        if self.path == '/state':
            payload, kind = json.dumps(view).encode(), 'application/json'
        elif self.path == '/':
            image = ('<img width="224" height="224" alt="QR подключения" src="data:image/svg+xml;base64,' + view['qr'] + '">') if view['qr'] else ''
            pairing = ('<section class="pairing-grid"><div>' + image + '</div><div class="pairing-details">'
                       '<p>Код подтверждения</p><p><strong>' + html.escape(view['code']) + '</strong></p><p class="pairing-url">' + html.escape(view['url']) +
                       '</p></div></section>') if image else ''
            content = ('<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
                       '<meta http-equiv="refresh" content="5"><title>Подключение Raspberry</title>'
                       '<style>*{box-sizing:border-box}body{font:17px/1.35 sans-serif;background:#f2f7fb;color:#193444;margin:12px;text-align:center}'
                       'main{max-width:760px;min-height:calc(100vh - 24px);min-height:calc(100dvh - 24px);margin:auto;display:flex;flex-direction:column;justify-content:center;gap:12px}'
                       'h1,p{margin:0}h1{font-size:26px;line-height:1.2}.pairing-grid{display:grid;grid-template-columns:224px minmax(0,1fr);align-items:center;gap:24px;text-align:center}'
                       '.pairing-details{min-width:0;display:grid;gap:12px}strong{font-size:38px;letter-spacing:6px}.pairing-url{font-size:14px;overflow-wrap:anywhere;user-select:text}'
                       'img{display:block;width:224px;height:224px;background:#fff}a{color:#195f99;display:inline-flex;min-height:44px;align-items:center;justify-content:center}'
                       '@media(max-width:560px){.pairing-grid{grid-template-columns:1fr;gap:10px}img{margin:auto;width:196px;height:196px}h1{font-size:24px}}'
                       '@media(min-width:561px) and (max-height:400px){body{margin:8px;font-size:15px}main{min-height:calc(100dvh - 16px);gap:8px}h1{font-size:23px}.pairing-grid{grid-template-columns:176px minmax(0,1fr)}img{width:176px;height:176px}strong{font-size:32px}}'
                       '</style><main><h1>Подключение Raspberry</h1><p>' + html.escape(view['message']) + '</p>'
                       + pairing + '<a href="http://127.0.0.1:8765/">Вернуться к киоску</a></main></html>')
            payload, kind = content.encode(), 'text/html; charset=utf-8'
        else:
            self.send_error(404)
            return
        self.send_response(200)
        for key, value in {'Content-Type': kind, 'Content-Length': str(len(payload)), 'Cache-Control': 'no-store',
                           'Referrer-Policy': 'no-referrer', 'X-Frame-Options': 'DENY',
                           'X-Content-Type-Options': 'nosniff',
                           'Content-Security-Policy': "default-src 'none'; img-src data:; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'"}.items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(payload)


def main():
    if os.name != 'posix' or os.geteuid() != 0:
        raise SystemExit('Run setup service as root on a fresh Raspberry')
    fresh_guard()
    thread = threading.Thread(target=worker, daemon=True)
    thread.start()
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()


if __name__ == '__main__':
    main()
