"""Stable endpoint allocation, scoped enrollment, and explicit primary cutover."""
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import ipaddress
import re
import secrets

from sqlalchemy.exc import IntegrityError
from app.config.settings import settings
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnauthorizedError, ValidationError
from app.models.school_device import DeviceInvitation, SchoolDevice, SchoolEndpoint
from app.schemas.school_device import DeviceEnrollment, DeviceOverview, DeviceView, GatewayManifest, GatewayRoute


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def utcnow():
    # Existing project columns intentionally use naive UTC timestamps.
    return datetime.now(timezone.utc).replace(tzinfo=None)


def reserve_endpoint(repository, school):
    """Caller owns the transaction; existing labels are immutable."""
    endpoint = repository.endpoint(school.id)
    if endpoint is not None:
        return endpoint
    number = re.search(r'(?<![0-9])[0-9]{1,8}(?![0-9])', school.short_name)
    slug = str(int(number[0])) if number else f's-{school.id}'
    if repository.slug_used(slug):
        slug = f'{slug}-{school.id}'
    endpoint = SchoolEndpoint(school_id=school.id, slug=slug, generation=0)
    repository.db.add(endpoint)
    repository.db.flush()
    return endpoint


class SchoolDeviceService:
    def __init__(self, repository):
        self.repo = repository

    @staticmethod
    def enabled():
        if settings.deployment_mode == 'local' or not settings.school_devices_enabled:
            raise NotFoundError('Управление устройствами пока не включено', code='devices_unavailable')
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9.-]{0,250}[a-z0-9])?', settings.school_domain):
            raise ValidationError('Проверьте домен школьных адресов')

    def require_school(self, school_id):
        school = self.repo.school(school_id)
        if school is None:
            raise NotFoundError('Школа не найдена')
        return school

    def hostname(self, endpoint):
        return f'{endpoint.slug}.{settings.school_domain}'

    def overview(self, school_id):
        self.enabled()
        school = self.require_school(school_id)
        try:
            endpoint = reserve_endpoint(self.repo, school)
            self.repo.db.commit()
            return self._overview(endpoint)
        except IntegrityError:
            self.repo.db.rollback()
            raise ConflictError('Адрес уже назначается. Повторите запрос', code='endpoint_collision')

    def _overview(self, endpoint):
        return DeviceOverview(school_id=endpoint.school_id, hostname=self.hostname(endpoint),
                              generation=endpoint.generation, primary_device_id=endpoint.primary_device_id,
                              devices=[DeviceView.model_validate(d) for d in self.repo.devices(endpoint.school_id)])

    def invite(self, school_id, role):
        self.enabled()
        school = self.require_school(school_id)
        if not school.is_active:
            raise ForbiddenError('Школа отключена')
        if role not in {'primary', 'terminal'}:
            raise ValidationError('Неизвестная роль устройства')
        if role == 'primary':
            try:
                key = base64.b64decode(settings.gateway_public_key, validate=True)
                assert len(key) == 32 and any(key)
                assert re.fullmatch(r'[a-zA-Z0-9.-]+:[0-9]{1,5}', settings.gateway_endpoint)
            except (AssertionError, ValueError):
                raise ValidationError('Сначала настройте общий шлюз')
        endpoint = reserve_endpoint(self.repo, school)
        if role == 'terminal' and not endpoint.primary_device_id:
            raise ConflictError('Сначала активируйте главную Raspberry')
        raw = secrets.token_urlsafe(48)
        expires = utcnow() + timedelta(minutes=10)
        # Only the latest invitation of each role may be used.
        self.repo.db.query(DeviceInvitation).filter_by(school_id=school_id, role=role).update(
            {'revoked': True}, synchronize_session=False)
        self.repo.db.add(DeviceInvitation(school_id=school_id, token_hash=digest(raw), role=role,
                                         generation=endpoint.generation, expires_at=expires, revoked=False))
        self.repo.db.commit()
        return {'invitation': raw, 'expires_at': expires.isoformat() + 'Z',
                'hostname': self.hostname(endpoint), 'role': role}

    def enroll(self, payload):
        self.enabled()
        now = utcnow()
        invite = self.repo.invitation(digest(payload.invitation))
        if invite is None or invite.revoked or invite.expires_at <= now:
            raise UnauthorizedError('Приглашение истекло или недействительно', code='invite_invalid')
        school = self.require_school(invite.school_id)
        endpoint = self.repo.endpoint(school.id)
        if not school.is_active or endpoint.generation != invite.generation:
            raise ConflictError('Конфигурация школы изменилась; создайте новое приглашение')
        identity = str(payload.device_id)
        if (invite.role == 'primary') != (payload.public_key is not None):
            raise ValidationError('WireGuard-ключ требуется только главной Raspberry')
        # Deterministic retry response: plaintext credentials are never stored.
        token = hmac.new(settings.secret_key.encode(),
                         f'gbou-device-v1:{payload.invitation}:{identity}'.encode(), hashlib.sha256).hexdigest()
        if invite.consumed_at is not None:
            device = self.repo.device(identity)
            if (invite.device_id != identity or device is None or device.public_key != payload.public_key
                    or device.token_hash != digest(token) or device.state == 'revoked'):
                raise UnauthorizedError('Приглашение уже использовано', code='invite_used')
            return self._enrollment(endpoint, device, token)
        if self.repo.device(identity) is not None:
            raise ConflictError('Устройство уже зарегистрировано; не копируйте идентификатор с другой SD')
        if not self.repo.consume(invite, identity, now):
            raise ConflictError('Приглашение уже использовано')
        try:
            device = SchoolDevice(school_id=school.id, device_id=identity, label=payload.label,
                                  role=invite.role, state='pending' if invite.role == 'primary' else 'active',
                                  token_hash=digest(token), public_key=payload.public_key,
                                  generation=endpoint.generation)
            self.repo.db.add(device)
            self.repo.db.flush()
            if device.role == 'primary':
                if device.id > 65532:
                    self.repo.db.rollback()
                    raise ConflictError('Пул адресов исчерпан; требуется расширение шлюза')
                device.tunnel_ip = str(ipaddress.IPv4Address('10.78.0.1') + device.id)
            self.repo.db.commit()
            return self._enrollment(endpoint, device, token)
        except IntegrityError:
            self.repo.db.rollback()
            raise ConflictError('Идентификатор или публичный ключ уже используются')

    def _enrollment(self, endpoint, device, token):
        return DeviceEnrollment(device_id=device.device_id, school_id=device.school_id, role=device.role,
                                building_id=device.building_id,
                                state=device.state, hostname=self.hostname(endpoint), token=token,
                                tunnel_ip=device.tunnel_ip,
                                gateway_public_key=settings.gateway_public_key if device.role == 'primary' else None,
                                gateway_endpoint=settings.gateway_endpoint if device.role == 'primary' else None,
                                gateway_tunnel_ip='10.77.203.1' if device.role == 'primary' else None)

    def authenticate(self, raw):
        self.enabled()
        device = self.repo.by_token(digest(raw)) if 40 <= len(raw) <= 128 else None
        if device is None:
            raise UnauthorizedError('Недействительный ключ устройства', code='device_unauthorized')
        school = self.require_school(device.school_id)
        if not school.is_active:
            raise ForbiddenError('Школа отключена')
        return device

    def device_status(self, raw):
        device = self.authenticate(raw)
        endpoint = self.repo.endpoint(device.school_id)
        device.last_seen_at = utcnow()
        self.repo.db.commit()
        return {'device_id': device.device_id, 'role': device.role, 'state': device.state,
                'hostname': self.hostname(endpoint), 'generation': endpoint.generation,
                'is_primary': endpoint.primary_device_id == device.device_id}

    def activate(self, school_id, device_id, payload):
        self.enabled()
        school = self.require_school(school_id)
        endpoint = self.repo.endpoint(school_id)
        device = self.repo.device(str(device_id))
        if not school.is_active or endpoint is None or device is None or device.school_id != school_id:
            raise NotFoundError('Устройство школы не найдено')
        if device.role != 'primary' or device.state != 'pending':
            raise ConflictError('Выберите ожидающую подключения главную Raspberry')
        if not payload.previous_primary_stopped or not payload.database_ready_and_backup_verified:
            raise ConflictError('Нужно остановить прежний сервер и проверить базу/резервную копию')
        generation = endpoint.generation
        if generation != payload.expected_generation or generation != device.generation:
            raise ConflictError('Главное устройство уже изменилось; обновите страницу', code='generation_changed')
        changed = self.repo.db.query(SchoolEndpoint).filter_by(
            id=endpoint.id, generation=generation,
        ).update({'generation': generation + 1, 'primary_device_id': device.device_id}, synchronize_session=False)
        if changed != 1:
            self.repo.db.rollback()
            raise ConflictError('Конкурентная замена устройства', code='generation_changed')
        # Pending competitors are revoked too; no later activation from stale generation.
        self.repo.db.query(SchoolDevice).filter(
            SchoolDevice.school_id == school_id, SchoolDevice.role == 'primary',
            SchoolDevice.device_id != device.device_id,
        ).update({'state': 'revoked'}, synchronize_session=False)
        device.state = 'active'
        device.generation = generation + 1
        self.repo.revoke_legacy_sync(school_id)
        self.repo.db.query(DeviceInvitation).filter_by(school_id=school_id).update(
            {'revoked': True}, synchronize_session=False)
        self.repo.db.commit()
        self.repo.db.expire_all()
        return self._overview(self.repo.endpoint(school_id))

    def revoke_terminal(self, school_id, device_id):
        self.enabled()
        self.require_school(school_id)
        device = self.repo.device(str(device_id))
        if device is None or device.school_id != school_id:
            raise NotFoundError('Устройство школы не найдено')
        if device.role != 'terminal':
            raise ConflictError('Главный узел заменяется только через проверенное переключение')
        device.state = 'revoked'
        self.repo.db.commit()
        return self._overview(self.repo.endpoint(school_id))

    def gateway_manifest(self, raw):
        self.enabled()
        expected = settings.gateway_manifest_token_hash
        if not re.fullmatch(r'[a-f0-9]{64}', expected) or not 40 <= len(raw) <= 128 or not hmac.compare_digest(digest(raw), expected):
            raise UnauthorizedError('Недействительный ключ шлюза', code='gateway_unauthorized')
        return GatewayManifest(routes=[GatewayRoute(school_id=e.school_id, hostname=self.hostname(e),
                              device_id=d.device_id, public_key=d.public_key, tunnel_ip=d.tunnel_ip,
                              generation=e.generation) for e, d in self.repo.manifest_rows()])
