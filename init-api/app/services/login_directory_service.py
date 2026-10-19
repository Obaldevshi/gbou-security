"""Separate pepper and an existing current-primary key; no credential lookup."""
import hashlib
import hmac
import re
from datetime import timedelta

from app.config.settings import settings
from app.core.exceptions import BaseError, ConflictError, ForbiddenError, NotFoundError
from app.schemas.login_directory import SchoolDestination
from app.services.school_device_service import utcnow


class LoginDirectoryService:
    def __init__(self, repository, devices):
        self.repo = repository
        self.devices = devices

    @staticmethod
    def enabled():
        if (settings.deployment_mode != 'cloud' or not settings.login_directory_enabled
                or not settings.school_devices_enabled):
            raise NotFoundError('Автоматическое подключение пока недоступно', code='directory_unavailable')
        if (len(settings.login_directory_pepper.encode()) < 32
                or hmac.compare_digest(settings.login_directory_pepper.encode(), settings.secret_key.encode())):
            raise BaseError('Справочник подключения не настроен', 503, 'directory_unavailable')

    @staticmethod
    def tag(digest):
        return hmac.new(settings.login_directory_pepper.encode(),
                        ('gbou-routing-tag-v1:' + digest).encode(), hashlib.sha256).hexdigest()

    def replace(self, raw_token, snapshot):
        self.enabled()
        device = self.devices.authenticate(raw_token)
        # Lock the same school row as activation/revocation before checking ownership.
        # Re-read after the lock: another transaction may have just replaced the Pi.
        self.repo.db.expire_all()
        endpoint = self.devices.repo.endpoint(device.school_id)
        if (device.role != 'primary' or device.state != 'active' or endpoint is None
                or endpoint.primary_device_id != device.device_id):
            raise ForbiddenError('Только действующая главная Raspberry публикует указатели')
        if snapshot.generation != endpoint.generation or device.generation != endpoint.generation:
            raise ConflictError('Поколение устройства изменилось', code='generation_changed')
        tags = {self.tag(value) for value in snapshot.login_digests}
        self.repo.prune(utcnow())
        self.repo.replace(device.school_id, tags, endpoint.generation, utcnow() + timedelta(hours=24))
        self.repo.db.commit()
        return {'published': len(tags)}

    def resolve(self, digest):
        self.enabled()
        destinations = self.repo.destinations(self.tag(digest), utcnow())
        if len(destinations) != 1:
            raise NotFoundError('Школа не определена. Проверьте логин или укажите адрес школы вручную.',
                                code='school_not_resolved')
        endpoint = destinations[0]
        hostname = self.devices.hostname(endpoint)
        # Never return an arbitrary administrator/node supplied URL.
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.' +
                            re.escape(settings.school_domain), hostname):
            raise NotFoundError('Школа не определена', code='school_not_resolved')
        return SchoolDestination(school_id=endpoint.school_id, origin='https://' + hostname)
