from datetime import timedelta
from app.models.device_pairing import DevicePairing
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.user import UserRole
from .school_device_repository import SchoolDeviceRepository


class DevicePairingRepository(SchoolDeviceRepository):
    def pairing(self, request_id):
        return self.db.query(DevicePairing).filter_by(request_id=str(request_id)).with_for_update().first()

    def pairing_for_device(self, device_id):
        return self.db.query(DevicePairing).filter_by(device_id=str(device_id)).with_for_update().first()

    def available_slots(self, now, keep_device):
        # Only ephemeral pairing requests are pruned, never schools or devices.
        self.db.query(DevicePairing).filter(DevicePairing.device_id != keep_device,
            DevicePairing.expires_at < now - timedelta(days=1)).delete(synchronize_session=False)
        return self.db.query(DevicePairing).count() < 2048 and self.db.query(DevicePairing).filter(
            DevicePairing.state == 'waiting', DevicePairing.expires_at > now).count() < 256

    def schools_for(self, actor):
        query = self.db.query(School).filter(School.is_active.is_(True))
        if actor.role != UserRole.SUPER_ADMIN:
            query = query.filter(School.id == actor.school_id)
        return query.order_by(School.id).limit(500).all()

    def buildings(self, school_id):
        return self.db.query(SchoolBuilding).filter_by(school_id=school_id, is_active=True).order_by(SchoolBuilding.id).all()

    def building(self, school_id, building_id):
        return self.db.query(SchoolBuilding).filter_by(id=building_id, school_id=school_id, is_active=True).first()
