#!/usr/bin/env python3
"""Root-only Unix control for explicit, admin-authorized local QR rebinds.

No HTTP listener, passwords/JWTs in jobs, arbitrary commands, cloud activation,
database deletion or automatic transfer of a school's data to another school.
"""
import json
import os
from pathlib import Path
import re
import shutil
import socketserver
import subprocess
import threading
import time
import uuid
from urllib.error import HTTPError
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler

CLOUD = 'https://obaldevshi-gbou-security-ac8a.twc1.net'
SOCKET = Path('/run/gbou-device-rebind/control.sock')
STATE = Path('/var/lib/gbou-device-rebind')
DEVICE = Path('/etc/gbou-device')
DB = Path('/var/lib/gbou-local/school.sqlite3')
MARKER = Path('/var/lib/gbou-reprovision/in-progress')
SOURCE = Path('/opt/gbou-device-setup')
PYTHON = '/opt/gbou-local-api/.venv/bin/python'
MAX_BODY = 8192
LOCK = threading.Lock()
AUTH_LOCK = threading.Lock()
ATTEMPTS = []
BUSY = {'preparing', 'qr', 'restoring', 'ready_for_activation', 'starting'}


class ControlError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = build_opener(ProxyHandler({}), NoRedirect())


def cloud(path, body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = Request(CLOUD + '/api/v1/device-admin' + path, headers=headers,
                      data=None if body is None else json.dumps(body).encode())
    try:
        with OPENER.open(request, timeout=20) as response:
            raw = response.read(1048577)
            if len(raw) > 1048576:
                raise ValueError('Oversized control response')
            return json.loads(raw)
    except HTTPError as error:
        status = error.code if error.code in {401, 403, 409, 429} else 403 if error.code == 404 else 503
        raise ControlError(status, 'Вход не подтверждён. Нужен администратор этой школы с постоянным паролем.') from None


def descriptor():
    path = DEVICE / 'device.json'
    assert path.is_file() and not path.is_symlink() and path.stat().st_mode & 0o077 == 0
    data = json.loads(path.read_text())
    uuid.UUID(data['device_id'])
    assert isinstance(data['school_id'], int) and data['school_id'] > 0
    assert isinstance(data.get('building_id'), int) and data['building_id'] > 0
    assert data['role'] in {'primary', 'terminal'}
    assert re.fullmatch(r'[a-z0-9-]+\.gbousecurity\.ru', data['hostname'])
    return data


def authorize(payload, device):
    if payload.get('confirmation') != 'ОТВЯЗАТЬ':
        raise ControlError(422, 'Для подтверждения введите ОТВЯЗАТЬ.')
    login, password = payload.get('login'), payload.get('password')
    if not isinstance(login, str) or not 1 <= len(login.strip()) <= 255 or not isinstance(password, str) or not 1 <= len(password) <= 1024:
        raise ControlError(422, 'Введите логин и пароль администратора.')
    with AUTH_LOCK:
        now = time.monotonic()
        ATTEMPTS[:] = [stamp for stamp in ATTEMPTS if now - stamp < 60]
        if len(ATTEMPTS) >= 5:
            raise ControlError(429, 'Много попыток на этом устройстве. Повторите через минуту.')
        ATTEMPTS.append(now)
    session = cloud('/login', {'login': login.strip().lower(), 'password': password})
    if session.get('password_change_required') or not isinstance(session.get('access_token'), str):
        raise ControlError(403, 'Сначала смените временный пароль в кабинете администратора.')
    token = session['access_token']
    context = cloud('/schools/' + str(device['school_id']), token=token)
    if context.get('networking_scope') == 'building':
        choices = [item for item in context.get('building_overviews', [])
                   if item.get('building_id') == device['building_id']]
        if len(choices) != 1:
            raise ControlError(403, 'Регистрация корпуса не подтверждена.')
        overview = choices[0]
    else:
        overview = context['overview']
    matches = [item for item in overview['devices'] if item['device_id'] == device['device_id']]
    if (overview['school_id'] != device['school_id'] or overview['hostname'] != device['hostname']
            or len(matches) != 1 or matches[0].get('building_id') != device['building_id']
            or matches[0]['role'] != device['role'] or matches[0]['state'] != 'active'):
        raise ControlError(403, 'Регистрация устройства не подтверждена. Нужна проверка администратора.')
    if device['role'] == 'primary' and overview['primary_device_id'] != device['device_id']:
        raise ControlError(409, 'Устройство больше не является главным сервером.')
    return token  # only to revoke this terminal; never written to a file


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=600)
    if result.returncode:
        raise RuntimeError('Local operation stopped; inspect private state')
    return result.stdout.strip()


def save(job):
    candidate = STATE / 'job.next'
    # Fixed, root-owned directory. No credential/identifier supplied paths.
    descriptor_fd = os.open(candidate, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor_fd, 'w') as stream:
        json.dump(job, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(candidate, STATE / 'job.json')
    fd = os.open(STATE, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def load():
    path = STATE / 'job.json'
    if not path.exists():
        return None
    assert not path.is_symlink()
    return json.loads(path.read_text())


def status():
    job = load()
    if job and job['phase'] != 'idle':
        result = {key: job[key] for key in ('phase', 'message', 'role', 'hostname')}
        if job['phase'] == 'qr':
            try:
                with OPENER.open('http://127.0.0.1:8766/state', timeout=2) as response:
                    view = json.loads(response.read(524289))
                # Only agent's public QR/code, never its private state file.
                if (view.get('url', '').startswith('https://gbousecurity.ru/#/connect/')
                        and re.fullmatch('[0-9]{6}', view.get('code', ''))
                        and len(view.get('qr', '')) < 400000):
                    result.update({key: view[key] for key in ('qr', 'code', 'url')})
            except (OSError, ValueError, KeyError):
                pass
        return result
    device = descriptor()
    return {'phase': 'idle', 'message': 'Настройки привязки доступны только администратору школы.',
            'role': device['role'], 'hostname': device['hostname']}


def progress(job, phase, message):
    job.update(phase=phase, message=message)
    save(job)


def primary_step(action):
    args = [PYTHON, str(SOURCE / 'rebind_primary.py'), action, '--apply']
    if action == 'prepare':
        args += ['--source', str(SOURCE)]
    return run(*args)


def resume_primary(job):
    if not MARKER.is_file():
        raise RuntimeError('No verified rebind marker')
    folder = Path(MARKER.read_text().strip())
    assert folder.parent == Path('/var/lib/gbou-reprovision') and folder.resolve() == folder
    state = json.loads((folder / 'state.json').read_text())
    assert (state.get('managed_by') == 'local-rebind-v1' and state['school_id'] == job['school_id']
            and state['building_id'] == job['building_id'])
    if state['phase'] in {'qr_ready', 'qr_waiting_network'}:
        assert not DB.exists() and not Path('/etc/wireguard/gbou-wg.conf').exists()
        run('systemctl', 'start', 'gbou-device-setup.service')
        progress(job, 'qr', 'Отсканируйте QR из профиля администратора. Выберите прежнюю школу, прежний корпус и главное устройство.')
        while True:
            if (DEVICE / 'device.json').exists():
                new = descriptor()
                if (new['school_id'] != job['school_id'] or new['building_id'] != job['building_id']
                        or new['role'] != 'primary'):
                    raise ControlError(409, 'Выбран другой корпус, школа или роль. Старая база сохранена и НЕ передана новому назначению. Обратитесь к администратору проекта.')
                if json.loads((DEVICE / 'pairing-state.json').read_text()).get('completed'):
                    break
            time.sleep(3)
        # Record the validated QR phase if initial bounded wait ran out of time.
        if state['phase'] == 'qr_waiting_network':
            state['phase'] = 'qr_ready'
            save_operation_state(folder, state)
        progress(job, 'restoring', 'Проверяем резервную копию и возвращаем прежнюю школьную базу…')
        primary_step('restore-pending')
    elif state['phase'] not in {'data_ready_for_activation', 'activated_but_fenced_retry_required'}:
        raise RuntimeError('Interrupted preflight requires operator inspection')
    progress(job, 'ready_for_activation', 'База и резервная копия проверены. Теперь в кабинете администратора можно активировать это главное устройство.')
    while True:
        device = descriptor()
        token = (DEVICE / 'device.token').read_text().strip()
        request = Request(CLOUD + '/api/v1/devices/heartbeat', data=b'', headers={'X-School-Device-Token': token})
        try:
            with OPENER.open(request, timeout=20) as response:
                current = json.load(response)
            if current.get('state') == 'active' and current.get('is_primary') is True and current.get('device_id') == device['device_id']:
                break
        except (OSError, ValueError):
            pass
        time.sleep(5)
    progress(job, 'starting', 'Проверяем новое соединение и запускаем школьный сервер…')
    primary_step('finish-active')
    primary_step('backup-current')


def save_operation_state(folder, state):
    # Reuse the same fsync/atomic writer as the audited primary helper.
    import rebind_primary
    rebind_primary.record(folder, state)


def prepare_terminal(job, token):
    assert not DB.exists() and not Path('/etc/wireguard/gbou-wg.conf').exists()
    assert subprocess.run(['systemctl', 'is-active', '--quiet', 'gbou-local-api.service'], capture_output=True).returncode != 0
    folder = STATE / ('terminal-before-' + job['id'])
    folder.mkdir(mode=0o700)
    shutil.copy2('/etc/gbou-kiosk.conf', folder / 'kiosk.conf')
    # Revocation is own-school/own-terminal only, using the verified admin JWT.
    cloud('/schools/' + str(job['school_id']) + '/devices/' + job['device_id'] + '/revoke', {}, token)
    run('systemctl', 'stop', 'gbou-device-terminal.timer', 'gbou-device-terminal.service',
        'gbou-device-heartbeat.timer', 'gbou-device-heartbeat.service', 'gbou-device-setup.service')
    assert DEVICE.resolve() == DEVICE and not DEVICE.is_symlink()
    os.rename(DEVICE, folder / 'device-before')
    DEVICE.mkdir(mode=0o700)
    job['terminal_prepared'] = True
    save(job)


def resume_terminal(job):
    assert job.get('terminal_prepared') and not DB.exists() and not Path('/etc/wireguard/gbou-wg.conf').exists()
    run('systemctl', 'start', 'gbou-device-setup.service')
    progress(job, 'qr', 'Отсканируйте QR из профиля администратора и выберите дочернее устройство.')
    while not (DEVICE / 'device.json').exists():
        time.sleep(3)
    new = descriptor()
    if new['role'] != 'terminal':
        raise ControlError(409, 'Назначено главное устройство. Для него требуется отдельная установка сервера; пустая база не создавалась.')
    progress(job, 'starting', 'Подключаем дочерний киоск к школьному серверу…')
    # Existing helper requires current active registration + valid school TLS.
    for _ in range(60):
        try:
            run('/usr/bin/python3', str(SOURCE / 'finish_terminal.py'))
            run('systemctl', 'enable', '--now', 'gbou-device-terminal.timer', 'gbou-device-heartbeat.timer')
            return
        except RuntimeError:
            time.sleep(5)
    raise RuntimeError('School server unavailable; preserved configuration requires inspection')


def work(job, token=None, resumed=False):
    try:
        if job['role'] == 'primary':
            if not resumed:
                primary_step('prepare')
            resume_primary(job)
        else:
            if not resumed:
                prepare_terminal(job, token)
            resume_terminal(job)
        job['hostname'] = descriptor()['hostname']
        progress(job, 'completed', 'Устройство подключено. Можно закрыть окно и войти как охранник.')
    except ControlError as error:
        progress(job, 'error', error.message)
    except Exception:
        progress(job, 'error', 'Операция остановлена для проверки. Данные сохранены. Не удаляйте файлы и не активируйте непроверенную базу; обратитесь к администратору проекта.')
    finally:
        LOCK.release()


def submit(payload):
    if not LOCK.acquire(blocking=False):
        raise ControlError(409, 'Перепривязка уже выполняется.')
    handed_off = False
    try:
        previous = load()
        if MARKER.exists() or (previous and previous['phase'] not in {'idle', 'completed'}):
            raise ControlError(409, 'Предыдущая операция не завершена. Сначала проверьте её состояние.')
        device = descriptor()
        if device['role'] == 'primary' and (not DB.is_file() or not Path(PYTHON).is_file()):
            raise ControlError(409, 'Не найден установленный школьный сервер. Данные не изменены.')
        token = authorize(payload, device)
        job = {'id': str(uuid.uuid4()), 'role': device['role'], 'device_id': device['device_id'],
               'school_id': device['school_id'], 'building_id': device['building_id'], 'hostname': device['hostname'],
               'phase': 'preparing', 'message': 'Подготавливаем безопасную резервную копию…'}
        save(job)  # Deliberately no password, login or admin JWT.
        threading.Thread(target=work, args=(job, token), daemon=True).start()
        handed_off = True
        return status()
    finally:
        if not handed_off:
            LOCK.release()


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        self.request.settimeout(65)
        try:
            raw = self.rfile.readline(MAX_BODY + 1)
            if len(raw) > MAX_BODY or not raw.endswith(b'\n'):
                raise ControlError(413, 'Слишком большой запрос.')
            request = json.loads(raw)
            if request.get('action') == 'status':
                data = status()
            elif request.get('action') == 'rebind':
                data = submit(request.get('payload', {}))
            else:
                raise ControlError(404, 'Действие недоступно.')
            result = {'status': 200, 'data': data}
        except ControlError as error:
            result = {'status': error.status, 'data': {'message': error.message}}
        except Exception:
            result = {'status': 503, 'data': {'message': 'Управление устройством требует проверки администратора.'}}
        self.wfile.write(json.dumps(result).encode() + b'\n')


def make_server():
    # Linux transport is intentionally unavailable on Windows: no TCP fallback.
    if not hasattr(socketserver, 'UnixStreamServer'):
        raise RuntimeError('A Linux Unix socket is required')
    class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
        daemon_threads = True
    return Server(str(SOCKET), Handler)


def main():
    assert os.geteuid() == 0
    STATE.mkdir(mode=0o700, exist_ok=True)
    assert not STATE.is_symlink()
    STATE.chmod(0o700)
    if SOCKET.exists():
        assert SOCKET.is_socket() and not SOCKET.is_symlink()
        SOCKET.unlink()  # This service's stale socket only, never a data file.
    server = make_server()
    SOCKET.chmod(0o600)
    job = load()
    if job and job['phase'] in BUSY:
        LOCK.acquire()
        threading.Thread(target=work, args=(job, None, True), daemon=True).start()
    server.serve_forever()


if __name__ == '__main__':
    main()
