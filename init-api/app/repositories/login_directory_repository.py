from app.models.login_directory import BuildingLoginDirectoryEntry, LoginDirectoryEntry
from app.models.school import School
from app.models.school_device import BuildingEndpoint, SchoolDevice, SchoolEndpoint
from app.models.school_building import SchoolBuilding


class LoginDirectoryRepository:
    def __init__(self, db):
        self.db = db

    def replace(self, school_id, tags, generation, expires_at, *, endpoint_id=None):
        if endpoint_id is not None:
            self.db.query(BuildingLoginDirectoryEntry).filter_by(endpoint_id=endpoint_id).delete(synchronize_session='fetch')
            self.db.add_all(BuildingLoginDirectoryEntry(endpoint_id=endpoint_id, lookup_tag=tag,
                           generation=generation, expires_at=expires_at) for tag in tags)
            return
        self.db.query(LoginDirectoryEntry).filter_by(school_id=school_id).delete(synchronize_session='fetch')
        self.db.add_all(LoginDirectoryEntry(school_id=school_id, lookup_tag=tag,
                       generation=generation, expires_at=expires_at) for tag in tags)

    def prune(self, now):
        self.db.query(LoginDirectoryEntry).filter(LoginDirectoryEntry.expires_at <= now).delete(synchronize_session='fetch')
        self.db.query(BuildingLoginDirectoryEntry).filter(BuildingLoginDirectoryEntry.expires_at <= now).delete(synchronize_session='fetch')

    def destinations(self, tag, now, *, building_scoped=False):
        if building_scoped:
            return self.db.query(BuildingEndpoint).join(BuildingLoginDirectoryEntry,
                BuildingLoginDirectoryEntry.endpoint_id == BuildingEndpoint.id,
            ).join(School, School.id == BuildingEndpoint.school_id).join(
                SchoolBuilding, SchoolBuilding.id == BuildingEndpoint.building_id,
            ).join(SchoolDevice, SchoolDevice.device_id == BuildingEndpoint.primary_device_id).filter(
                BuildingLoginDirectoryEntry.lookup_tag == tag, BuildingLoginDirectoryEntry.expires_at > now,
                BuildingLoginDirectoryEntry.generation == BuildingEndpoint.generation,
                School.is_active.is_(True), SchoolBuilding.is_active.is_(True),
                SchoolBuilding.school_id == BuildingEndpoint.school_id,
                SchoolDevice.state == 'active', SchoolDevice.role == 'primary',
                SchoolDevice.school_id == BuildingEndpoint.school_id,
                SchoolDevice.building_id == BuildingEndpoint.building_id,
                SchoolDevice.generation == BuildingEndpoint.generation,
            ).order_by(BuildingEndpoint.school_id, BuildingEndpoint.building_id).limit(65).all()
        return self.db.query(SchoolEndpoint).join(
            LoginDirectoryEntry, LoginDirectoryEntry.school_id == SchoolEndpoint.school_id,
        ).join(School, School.id == SchoolEndpoint.school_id).join(
            SchoolDevice, SchoolDevice.device_id == SchoolEndpoint.primary_device_id,
        ).filter(LoginDirectoryEntry.lookup_tag == tag, LoginDirectoryEntry.expires_at > now,
                 LoginDirectoryEntry.generation == SchoolEndpoint.generation,
                 School.is_active.is_(True), SchoolDevice.role == 'primary',
                 SchoolDevice.state == 'active', SchoolDevice.school_id == SchoolEndpoint.school_id,
                 SchoolDevice.generation == SchoolEndpoint.generation).limit(2).all()
