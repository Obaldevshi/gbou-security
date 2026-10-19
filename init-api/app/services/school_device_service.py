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
from app.models.school_device import BuildingEndpoint, DeviceInvitation, SchoolDevice, SchoolEndpoint
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
    repository.lock_address_namespace()
    number = re.search(r'(?<![0-9])[0-9]{1,8}(?![0-9])', school.short_name)
    slug = str(int(number[0])) if number else f's-{school.id}'
    if repository.building_slug_used(slug):
        slug = f'{slug}-{school.id}'
    if repository.building_slug_used(slug):
        slug = f's-{school.id}'
    if repository.building_slug_used(slug):
        raise ConflictError('Адрес уже занят', code='endpoint_collision')
    endpoint = SchoolEndpoint(school_id=school.id, slug=slug, generation=0)
    repository.db.add(endpoint)
    repository.db.flush()
    return endpoint


def reserve_building_endpoint(repository, school, building_id):
    """Reserve under the school's row lock, never steal a live legacy route."""
    if building_id is None or repository.building(school.id, building_id) is None:
        raise NotFoundError('Выберите активный корпус школы', code='building_required')
    endpoint = repository.endpoint(school.id, building_id)
    if endpoint is not None:
        return endpoint
    repository.lock_address_namespace()
    legacy = reserve_endpoint(repository, school)
    if legacy.primary_device_id:
        primary = repository.device(legacy.primary_device_id)
        if primary is not None and primary.building_id == building_id:
            # A registry populated while 016 was installed but not enabled must
            # be adopted explicitly; don't copy an outdated generation silently.
            raise ConflictError('Сначала проверьте перенос действующего реестра корпуса', code='building_adoption_required')
    ordinal = repository.building_position(school.id, building_id)
    slug = f'{legacy.slug}-{ordinal}'
    if repository.building_slug_used(slug):
        slug = f'{slug}-b{building_id}'
    if repository.building_slug_used(slug) or len(slug) > 63:
        raise ConflictError('Адрес корпуса уже занят', code='endpoint_collision')
    endpoint = BuildingEndpoint(school_id=school.id, building_id=building_id, slug=slug, generation=0)
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
        return endpoint.legacy_hostname or f'{endpoint.slug}.{settings.school_domain}'

    def endpoint_for_device(self, device):
        if settings.building_nodes_enabled:
            if device.building_id is None or not self.repo.building(device.school_id, device.building_id):
                raise ConflictError('Устройство не назначено активному корпусу', code='building_required')
            endpoint = self.repo.endpoint(device.school_id, device.building_id)
        else:
            endpoint = self.repo.endpoint(device.school_id)
        if endpoint is None:
            raise ConflictError('Сетевой адрес устройства не зарегистрирован', code='endpoint_missing')
        return endpoint

    def overview(self, school_id, building_id=None):
        self.enabled()
        school = self.require_school(school_id)
        try:
            endpoint = (reserve_building_endpoint(self.repo, school, building_id)
                        if settings.building_nodes_enabled else reserve_endpoint(self.repo, school))
            self.repo.db.commit()
            return self._overview(endpoint)
        except IntegrityError:
            self.repo.db.rollback()
            raise ConflictError('Адрес уже назначается. Повторите запрос', code='endpoint_collision')

    def _overview(self, endpoint):
        return DeviceOverview(school_id=endpoint.school_id, hostname=self.hostname(endpoint),
                              building_id=getattr(endpoint, 'building_id', None),
                              generation=endpoint.generation, primary_device_id=endpoint.primary_device_id,
                              devices=[DeviceView.model_validate(d) for d in self.repo.devices(
                                  endpoint.school_id, getattr(endpoint, 'building_id', None))])

    def invite(self, school_id, role, building_id=None):
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
        endpoint = (reserve_building_endpoint(self.repo, school, building_id)
                    if settings.building_nodes_enabled else reserve_endpoint(self.repo, school))
        scope_building = getattr(endpoint, 'building_id', None)
        if role == 'terminal' and not endpoint.primary_device_id:
            raise ConflictError('Сначала активируйте главную Raspberry')
        raw = secrets.token_urlsafe(48)
        expires = utcnow() + timedelta(minutes=10)
        # Only the latest invitation of each role may be used.
        self.repo.db.query(DeviceInvitation).filter_by(school_id=school_id, role=role, building_id=scope_building).update(
            {'revoked': True}, synchronize_session=False)
        self.repo.db.add(DeviceInvitation(school_id=school_id, token_hash=digest(raw), role=role,
                                         building_id=scope_building,
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
        if settings.building_nodes_enabled and (invite.building_id is None or not self.repo.building(school.id, invite.building_id)):
            raise ConflictError('Создайте новое приглашение с выбором корпуса', code='building_required')
        endpoint = self.repo.endpoint(school.id, invite.building_id if settings.building_nodes_enabled else None)
        if endpoint is None:
            raise ConflictError('Адрес корпуса не зарегистрирован')
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
                                  building_id=getattr(endpoint, 'building_id', None),
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
                                node_scope='building' if settings.building_nodes_enabled else 'school',
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
        endpoint = self.endpoint_for_device(device)
        device.last_seen_at = utcnow()
        self.repo.db.commit()
        return {'device_id': device.device_id, 'role': device.role, 'state': device.state,
                'school_id': device.school_id, 'building_id': device.building_id,
                'hostname': self.hostname(endpoint), 'generation': endpoint.generation,
                'is_primary': endpoint.primary_device_id == device.device_id}

    def activate(self, school_id, device_id, payload):
        self.enabled()
        school = self.require_school(school_id)
        device = self.repo.device(str(device_id))
        if not school.is_active or device is None or device.school_id != school_id:
            raise NotFoundError('Устройство школы не найдено')
        endpoint = self.endpoint_for_device(device)
        if device.role != 'primary' or device.state != 'pending':
            raise ConflictError('Выберите ожидающую подключения главную Raspberry')
        if not payload.previous_primary_stopped or not payload.database_ready_and_backup_verified:
            raise ConflictError('Нужно остановить прежний сервер и проверить базу/резервную копию')
        generation = endpoint.generation
        if generation != payload.expected_generation or generation != device.generation:
            raise ConflictError('Главное устройство уже изменилось; обновите страницу', code='generation_changed')
        changed = self.repo.db.query(type(endpoint)).filter_by(
            id=endpoint.id, generation=generation,
        ).update({'generation': generation + 1, 'primary_device_id': device.device_id}, synchronize_session=False)
        if changed != 1:
            self.repo.db.rollback()
            raise ConflictError('Конкурентная замена устройства', code='generation_changed')
        # Pending competitors are revoked too; no later activation from stale generation.
        competitors = self.repo.db.query(SchoolDevice).filter(
            SchoolDevice.school_id == school_id, SchoolDevice.role == 'primary',
            SchoolDevice.device_id != device.device_id,
        )
        if settings.building_nodes_enabled:
            competitors = competitors.filter(SchoolDevice.building_id == device.building_id)
        competitors.update({'state': 'revoked'}, synchronize_session=False)
        device.state = 'active'
        device.generation = generation + 1
        self.repo.revoke_legacy_sync(school_id)
        invitations = self.repo.db.query(DeviceInvitation).filter_by(school_id=school_id)
        if settings.building_nodes_enabled:
            invitations = invitations.filter_by(building_id=device.building_id)
        invitations.update(
            {'revoked': True}, synchronize_session=False)
        self.repo.db.commit()
        self.repo.db.expire_all()
        return self._overview(self.endpoint_for_device(device))

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
        return self._overview(self.endpoint_for_device(device))

    def gateway_manifest(self, raw):
        self.enabled()
        expected = settings.gateway_manifest_token_hash
        if not re.fullmatch(r'[a-f0-9]{64}', expected) or not 40 <= len(raw) <= 128 or not hmac.compare_digest(digest(raw), expected):
            raise UnauthorizedError('Недействительный ключ шлюза', code='gateway_unauthorized')
        return GatewayManifest(schema_version=2 if settings.building_nodes_enabled else 1,
                              routes=[GatewayRoute(school_id=e.school_id, hostname=self.hostname(e),
                              building_id=getattr(e, 'building_id', None),
                              device_id=d.device_id, public_key=d.public_key, tunnel_ip=d.tunnel_ip,
                              generation=e.generation) for e, d in self.repo.manifest_rows(
                                  building_scoped=settings.building_nodes_enabled)])
