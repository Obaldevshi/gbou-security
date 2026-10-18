"""Operator-only legacy adoption. No public route and no credential minting."""
import hmac
from sqlalchemy.exc import IntegrityError
from sqlalchemy import or_
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.school_building import SchoolBuilding
from app.models.school_device import SchoolDevice, SchoolEndpoint, DeviceInvitation
from app.models.school_node_credential import SchoolNodeCredential
from .school_device_service import SchoolDeviceService, digest, reserve_endpoint, utcnow


class DeviceAdoptionService(SchoolDeviceService):
    def adopt(self, payload, *, apply=False):
        self.enabled()
        if payload.school_id != 2:
            raise ForbiddenError('Этот legacy-переход разрешён только школе2036/ID2')
        if not payload.same_writer_verified or not payload.backup_restore_verified:
            raise ConflictError('Нужна проверка того же writer и восстановления USB-копии')
        school = self.require_school(payload.school_id)
        if not school.is_active:
            raise ForbiddenError('Школа отключена')
        endpoint = self.repo.endpoint(school.id)
        credential = self.repo.db.query(SchoolNodeCredential).filter_by(school_id=school.id).with_for_update().first()
        if not credential or not hmac.compare_digest(digest(credential.token_hash), payload.credential_fingerprint):
            raise ConflictError('Отпечаток существующего ключа не совпал')
        building = self.repo.db.query(SchoolBuilding).filter_by(id=payload.building_id, school_id=school.id, is_active=True).first()
        if not building:
            raise NotFoundError('Активный корпус школы не найден')
        device = self.repo.device(str(payload.device_id))
        if endpoint and endpoint.primary_device_id == str(payload.device_id):
            if (device and device.school_id == school.id and device.role == 'primary' and device.state == 'active'
                    and device.public_key == payload.public_key and device.tunnel_ip == payload.tunnel_ip
                    and device.token_hash == credential.token_hash and device.building_id == payload.building_id
                    and endpoint.legacy_hostname == payload.hostname
                    and endpoint.generation == payload.expected_generation + 1 and not credential.is_active):
                return {'state': 'already_adopted', 'school_id': school.id,
                        'device_id': device.device_id, 'hostname': self.hostname(endpoint), 'generation': endpoint.generation}
            raise ConflictError('Регистрация не совпадает с действующим устройством')
        if (not credential.is_active or device or self.repo.devices(school.id)
                or (endpoint and (endpoint.primary_device_id is not None or endpoint.generation != payload.expected_generation))
                or (endpoint is None and payload.expected_generation != 0)):
            raise ConflictError('Реестр уже изменён; adoption остановлен')
        if self.repo.db.query(SchoolEndpoint).filter(SchoolEndpoint.school_id != school.id,
                or_(SchoolEndpoint.legacy_hostname == payload.hostname,
                    SchoolEndpoint.slug == payload.hostname.split('.')[0])).first():
            raise ConflictError('Старый адрес уже занят другой школой')
        result = {'state': 'validated', 'school_id': school.id, 'device_id': str(payload.device_id),
                  'hostname': payload.hostname, 'generation': payload.expected_generation + 1}
        if not apply:
            self.repo.db.rollback()
            return result
        try:
            endpoint = endpoint or reserve_endpoint(self.repo, school)
            changed = self.repo.db.query(SchoolEndpoint).filter_by(id=endpoint.id,
                generation=payload.expected_generation, primary_device_id=None).update({
                    'generation': payload.expected_generation + 1, 'primary_device_id': str(payload.device_id),
                    'legacy_hostname': payload.hostname}, synchronize_session=False)
            if changed != 1:
                raise ConflictError('Конкурентное изменение реестра')
            device = SchoolDevice(school_id=school.id, building_id=payload.building_id,
                device_id=str(payload.device_id), label=payload.label, role='primary', state='active',
                token_hash=credential.token_hash, public_key=payload.public_key,
                tunnel_ip=payload.tunnel_ip, generation=payload.expected_generation + 1, last_seen_at=utcnow())
            self.repo.db.add(device)
            credential.is_active = False
            self.repo.db.query(DeviceInvitation).filter_by(school_id=school.id).update({'revoked': True})
            self.repo.db.commit()
        except (IntegrityError, ConflictError):
            self.repo.db.rollback()
            raise ConflictError('Не удалось атомарно принять устройство; изменения отменены')
        return result | {'state': 'adopted'}

    def rollback_adoption(self, school_id, device_id, expected_generation):
        self.enabled()
        self.require_school(school_id)
        endpoint = self.repo.endpoint(school_id)
        device = self.repo.device(str(device_id))
        legacy = self.repo.db.query(SchoolNodeCredential).filter_by(school_id=school_id).with_for_update().first()
        if (school_id != 2 or not endpoint or not device or not legacy or len(self.repo.devices(school_id)) != 1
                or endpoint.primary_device_id != device.device_id or endpoint.generation != expected_generation
                or device.school_id != school_id or device.token_hash != legacy.token_hash or device.state != 'active'
                or endpoint.legacy_hostname != 'school-2036.gbousecurity.ru' or device.tunnel_ip != '10.77.203.2'):
            raise ConflictError('Небезопасный откат: реестр изменился')
        endpoint.primary_device_id = None
        endpoint.generation += 1
        legacy.is_active = True
        device.state = 'revoked'
        self.repo.db.commit()
        return {'state': 'legacy_restored', 'generation': endpoint.generation}
