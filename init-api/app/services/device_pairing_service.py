from datetime import timedelta
import hashlib
import hmac
import ipaddress
import uuid
from sqlalchemy.exc import IntegrityError
from app.config.settings import settings
from app.core.exceptions import BaseError, ConflictError, ForbiddenError, NotFoundError, UnauthorizedError
from app.models.device_pairing import DevicePairing
from app.models.school_device import SchoolDevice
from app.models.user import UserRole
from .school_device_service import SchoolDeviceService, digest, utcnow, reserve_endpoint


class DevicePairingService(SchoolDeviceService):
    @staticmethod
    def enabled():
        SchoolDeviceService.enabled()
        if not settings.device_pairing_enabled:
            raise NotFoundError('QR-подключение пока не включено')

    @staticmethod
    def proof(value):
        return hmac.new(settings.secret_key.encode(), value.encode(), hashlib.sha256).hexdigest()

    def require_owner(self, actor, school_id):
        if actor.role not in {UserRole.SCHOOL_ADMIN, UserRole.SUPER_ADMIN}:
            raise ForbiddenError('Требуется администратор')
        if actor.role != UserRole.SUPER_ADMIN and actor.school_id != school_id:
            raise NotFoundError('Школа не найдена')
        school = self.require_school(school_id)
        if not school.is_active:
            raise ForbiddenError('Школа отключена')
        return school

    def context(self, actor):
        self.enabled()
        return {'schools': [{'id': s.id, 'name': s.short_name} for s in self.repo.schools_for(actor)]}

    def school_context(self, actor, school_id):
        self.enabled()
        self.require_owner(actor, school_id)
        overview = self.overview(school_id)
        return {'overview': overview.model_dump(mode='json'),
                'buildings': [{'id': b.id, 'name': b.name} for b in self.repo.buildings(school_id)]}

    def start(self, payload):
        self.enabled()
        validated = payload.validated_device()
        identity, now = str(payload.device_id), utcnow()
        if self.repo.device(identity):
            raise ConflictError('Устройство уже зарегистрировано. Не копируйте SD с identity')
        row = self.repo.pairing_for_device(identity)
        poll_hash = digest(payload.poll_token)
        if row and row.expires_at > now and row.state != 'expired':
            if row.poll_hash != poll_hash or row.public_key != validated.public_key or row.state != 'waiting':
                raise ConflictError('На устройстве уже есть запрос подключения')
        else:
            if not self.repo.available_slots(now, identity):
                raise BaseError('Слишком много запросов подключения. Повторите позже', 429, 'pairing_busy')
            if row is None:
                row = DevicePairing(device_id=identity)
                self.repo.db.add(row)
            row.request_id, row.poll_hash = str(uuid.uuid4()), poll_hash
            row.label, row.public_key = validated.label, validated.public_key
            row.expires_at, row.state, row.failed_checks = now + timedelta(minutes=10), 'waiting', 0
        code = f'{int(self.proof("pair-code:" + row.request_id + ":" + payload.poll_token)[:12], 16) % 1000000:06d}'
        row.code_hash = self.proof('check:' + row.request_id + ':' + code)
        try:
            self.repo.db.commit()
        except IntegrityError:
            self.repo.db.rollback()
            raise ConflictError('Запрос уже создаётся. Повторите с тем же устройством')
        return {'request_id': row.request_id, 'verification_code': code,
                'expires_at': row.expires_at.isoformat() + 'Z',
                'qr_url': 'https://gbousecurity.ru/#/connect/' + row.request_id}

    def live(self, request_id):
        self.enabled()
        row = self.repo.pairing(request_id)
        if not row or row.expires_at <= utcnow() or row.state == 'expired':
            raise NotFoundError('QR-код истёк. Создайте новый на устройстве', code='pairing_expired')
        return row

    def preview(self, request_id):
        row = self.live(request_id)
        if row.state != 'waiting':
            raise ConflictError('Этот запрос уже подтверждён')
        return {'request_id': row.request_id, 'label': row.label,
                'expires_at': row.expires_at.isoformat() + 'Z',
                'fingerprint': digest(row.public_key)[:12]}

    def device_token(self, row):
        return self.proof('paired-device:' + row.request_id + ':' + row.poll_hash)

    def approve(self, actor, request_id, payload):
        self.enabled()
        row = self.live(request_id)
        school = self.require_owner(actor, payload.school_id)
        if not self.repo.building(school.id, payload.building_id):
            raise NotFoundError('Активный корпус не найден')
        if row.state != 'waiting' or self.repo.device(row.device_id):
            raise ConflictError('Устройство уже назначено')
        if not hmac.compare_digest(row.code_hash, self.proof('check:' + row.request_id + ':' + payload.code)):
            row.failed_checks += 1
            if row.failed_checks >= 5:
                row.state = 'expired'
            self.repo.db.commit()
            raise UnauthorizedError('Неверный код с экрана Raspberry', code='pairing_code_invalid')
        endpoint = reserve_endpoint(self.repo, school)
        if payload.role == 'terminal':
            primary = self.repo.device(endpoint.primary_device_id) if endpoint.primary_device_id else None
            if not primary or primary.school_id != school.id or primary.role != 'primary' or primary.state != 'active':
                raise ConflictError('Сначала подключите и активируйте главное устройство школы')
        if payload.role == 'primary':
            # Validate the existing gateway configuration without minting an invitation.
            import base64
            import re
            try:
                valid_key = len(base64.b64decode(settings.gateway_public_key, validate=True)) == 32
            except (ValueError, TypeError):
                valid_key = False
            if not valid_key or not re.fullmatch(r'[a-zA-Z0-9.-]+:[0-9]{1,5}', settings.gateway_endpoint):
                raise ConflictError('Общий шлюз ещё не настроен')
        device = SchoolDevice(device_id=row.device_id, school_id=school.id,
            building_id=payload.building_id, label=row.label, role=payload.role,
            state='pending' if payload.role == 'primary' else 'active',
            token_hash=digest(self.device_token(row)), generation=endpoint.generation,
            public_key=row.public_key if payload.role == 'primary' else None)
        try:
            self.repo.db.add(device)
            self.repo.db.flush()
            if device.role == 'primary':
                if device.id > 65532:
                    raise ConflictError('Пул адресов шлюза исчерпан')
                device.tunnel_ip = str(ipaddress.IPv4Address('10.78.0.1') + device.id)
            row.state = 'approved'
            row.expires_at = utcnow() + timedelta(minutes=10)
            self.repo.db.commit()
        except (IntegrityError, ConflictError):
            self.repo.db.rollback()
            raise ConflictError('Устройство/ключ уже назначены. Обновите страницу')
        return self.school_context(actor, school.id)

    def poll(self, request_id, raw, *, complete=False):
        row = self.live(request_id)
        if not 40 <= len(raw) <= 128 or not hmac.compare_digest(row.poll_hash, digest(raw)):
            raise UnauthorizedError('Недействительный запрос устройства')
        if row.state == 'completed':
            return {'state': 'completed'}
        if row.state == 'waiting':
            if complete:
                raise ConflictError('Администратор ещё не подтвердил устройство')
            return {'state': 'waiting'}
        device = self.repo.device(row.device_id)
        if not device or device.state == 'revoked' or device.token_hash != digest(self.device_token(row)):
            raise UnauthorizedError('Регистрация отозвана')
        school = self.require_school(device.school_id)
        if not school.is_active:
            raise ForbiddenError('Школа отключена')
        if complete:
            row.state = 'completed'
            self.repo.db.commit()
            return {'state': 'completed'}
        return {'state': 'approved', 'enrollment': self._enrollment(
            self.repo.endpoint(device.school_id), device, self.device_token(row)).model_dump(mode='json')}
