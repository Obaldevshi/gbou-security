from sqlalchemy.orm import Session
from app.models.school import School
from app.models.school_device import DeviceInvitation, SchoolDevice, SchoolEndpoint
from app.models.school_node_credential import SchoolNodeCredential


class SchoolDeviceRepository:
    def __init__(self, db: Session):
        self.db = db

    def school(self, school_id):
        # Serialize topology changes for one school on PostgreSQL.
        return self.db.query(School).filter(School.id == school_id).with_for_update().first()

    def endpoint(self, school_id):
        return self.db.query(SchoolEndpoint).filter_by(school_id=school_id).first()

    def slug_used(self, slug):
        return self.db.query(SchoolEndpoint.id).filter_by(slug=slug).first() is not None

    def devices(self, school_id):
        return self.db.query(SchoolDevice).filter_by(school_id=school_id).order_by(SchoolDevice.id).all()

    def device(self, device_id):
        return self.db.query(SchoolDevice).filter_by(device_id=device_id).first()

    def invitation(self, digest):
        return self.db.query(DeviceInvitation).filter_by(token_hash=digest).first()

    def consume(self, invite, device_id, now):
        return self.db.query(DeviceInvitation).filter(
            DeviceInvitation.id == invite.id, DeviceInvitation.consumed_at.is_(None),
            DeviceInvitation.revoked.is_(False), DeviceInvitation.expires_at > now,
        ).update({'consumed_at': now, 'device_id': device_id}, synchronize_session=False) == 1

    def by_token(self, digest):
        return self.db.query(SchoolDevice).filter(SchoolDevice.token_hash == digest,
                                                SchoolDevice.state != 'revoked').first()

    def current_primary_by_token(self, digest):
        device = self.by_token(digest)
        if device is None or device.role != 'primary' or device.state != 'active':
            return None
        endpoint = self.endpoint(device.school_id)
        return device if endpoint and endpoint.primary_device_id == device.device_id else None

    def revoke_legacy_sync(self, school_id):
        self.db.query(SchoolNodeCredential).filter_by(school_id=school_id).update(
            {'is_active': False}, synchronize_session=False)

    def manifest_rows(self):
        return self.db.query(SchoolEndpoint, SchoolDevice).join(
            SchoolDevice, SchoolDevice.device_id == SchoolEndpoint.primary_device_id,
        ).join(School, School.id == SchoolEndpoint.school_id).filter(
            School.is_active.is_(True), SchoolDevice.school_id == SchoolEndpoint.school_id,
            SchoolDevice.role == 'primary', SchoolDevice.state == 'active',
        ).order_by(SchoolEndpoint.school_id).all()
