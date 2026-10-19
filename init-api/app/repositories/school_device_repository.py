from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.exceptions import ConflictError
from app.models.school import School
from app.models.school_device import BuildingEndpoint, DeviceInvitation, SchoolDevice, SchoolEndpoint
from app.models.school_building import SchoolBuilding
from app.models.school_node_credential import SchoolNodeCredential


class SchoolDeviceRepository:
    def __init__(self, db: Session):
        self.db = db

    def school(self, school_id):
        # Serialize topology changes for one school on PostgreSQL.
        return self.db.query(School).filter(School.id == school_id).with_for_update().first()

    def endpoint(self, school_id, building_id=None):
        if building_id is not None:
            return self.db.query(BuildingEndpoint).filter_by(school_id=school_id, building_id=building_id).first()
        return self.db.query(SchoolEndpoint).filter_by(school_id=school_id).first()

    def lock_address_namespace(self):
        # Hostnames span BOTH legacy and building tables. PostgreSQL transactions
        # must serialize reservations across schools, not just within one school.
        if self.db.get_bind().dialect.name == 'postgresql':
            self.db.execute(text('SELECT pg_advisory_xact_lock(7042036001)'))

    def building(self, school_id, building_id):
        return self.db.query(SchoolBuilding).filter_by(id=building_id, school_id=school_id, is_active=True).first()

    def buildings(self, school_id):
        return self.db.query(SchoolBuilding).filter_by(school_id=school_id, is_active=True).order_by(SchoolBuilding.id).all()

    def building_position(self, school_id, building_id):
        # Include disabled buildings; once reserved a slug is never recomputed.
        return self.db.query(SchoolBuilding).filter(SchoolBuilding.school_id == school_id,
            SchoolBuilding.id <= building_id).count()

    def slug_used(self, slug):
        return self.db.query(SchoolEndpoint.id).filter_by(slug=slug).first() is not None

    def building_slug_used(self, slug):
        return self.slug_used(slug) or self.db.query(BuildingEndpoint.id).filter_by(slug=slug).first() is not None

    def devices(self, school_id, building_id=None):
        query = self.db.query(SchoolDevice).filter_by(school_id=school_id)
        if building_id is not None:
            query = query.filter_by(building_id=building_id)
        return query.order_by(SchoolDevice.id).all()

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

    def current_primary_by_token(self, digest, *, building_scoped=False):
        device = self.by_token(digest)
        if device is None or device.role != 'primary' or device.state != 'active':
            return None
        if building_scoped and device.building_id is None:
            return None
        endpoint = self.endpoint(device.school_id, device.building_id if building_scoped else None)
        # The current node must still receive its own is_active=false metadata.
        # Public routing/discovery remain restricted to active buildings.
        building_exists = (not building_scoped or self.db.query(SchoolBuilding.id).filter_by(
            id=device.building_id, school_id=device.school_id).first() is not None)
        return device if (endpoint and endpoint.primary_device_id == device.device_id
                          and endpoint.generation == device.generation
                          and building_exists) else None

    def validate_building_transition(self):
        # 016 can be installed with the gate OFF. Legacy QR replacements in that
        # interval must not be silently reverted when the gate is later enabled.
        rows = self.db.query(SchoolEndpoint, SchoolDevice).join(
            SchoolDevice, SchoolDevice.device_id == SchoolEndpoint.primary_device_id,
        ).filter(SchoolDevice.state == 'active', SchoolDevice.role == 'primary').all()
        for legacy, device in rows:
            scoped = self.endpoint(legacy.school_id, device.building_id) if device.building_id else None
            if (device.school_id != legacy.school_id or scoped is None
                    or scoped.primary_device_id != device.device_id or scoped.generation != legacy.generation
                    or scoped.generation != device.generation
                    or scoped.legacy_hostname != legacy.legacy_hostname or scoped.slug != legacy.slug):
                raise ConflictError('Сначала сверьте действующие узлы и перенесите legacy-реестр корпуса',
                                    code='building_adoption_required')

    def revoke_legacy_sync(self, school_id):
        self.db.query(SchoolNodeCredential).filter_by(school_id=school_id).update(
            {'is_active': False}, synchronize_session=False)

    def manifest_rows(self, *, building_scoped=False):
        endpoint = BuildingEndpoint if building_scoped else SchoolEndpoint
        query = self.db.query(endpoint, SchoolDevice).join(
            SchoolDevice, SchoolDevice.device_id == endpoint.primary_device_id,
        ).join(School, School.id == endpoint.school_id).filter(
            School.is_active.is_(True), SchoolDevice.school_id == endpoint.school_id,
            SchoolDevice.role == 'primary', SchoolDevice.state == 'active',
            SchoolDevice.generation == endpoint.generation,
        )
        if building_scoped:
            query = query.join(SchoolBuilding, SchoolBuilding.id == endpoint.building_id).filter(
                SchoolDevice.building_id == endpoint.building_id,
                SchoolBuilding.school_id == endpoint.school_id, SchoolBuilding.is_active.is_(True))
        return query.order_by(endpoint.school_id, endpoint.id).all()
