from app.models.login_directory import LoginDirectoryEntry
from app.models.school import School
from app.models.school_device import SchoolDevice, SchoolEndpoint


class LoginDirectoryRepository:
    def __init__(self, db):
        self.db = db

    def replace(self, school_id, tags, generation, expires_at):
        self.db.query(LoginDirectoryEntry).filter_by(school_id=school_id).delete(synchronize_session='fetch')
        self.db.add_all(LoginDirectoryEntry(school_id=school_id, lookup_tag=tag,
                       generation=generation, expires_at=expires_at) for tag in tags)

    def prune(self, now):
        self.db.query(LoginDirectoryEntry).filter(LoginDirectoryEntry.expires_at <= now).delete(synchronize_session='fetch')

    def destinations(self, tag, now):
        return self.db.query(SchoolEndpoint).join(
            LoginDirectoryEntry, LoginDirectoryEntry.school_id == SchoolEndpoint.school_id,
        ).join(School, School.id == SchoolEndpoint.school_id).join(
            SchoolDevice, SchoolDevice.device_id == SchoolEndpoint.primary_device_id,
        ).filter(LoginDirectoryEntry.lookup_tag == tag, LoginDirectoryEntry.expires_at > now,
                 LoginDirectoryEntry.generation == SchoolEndpoint.generation,
                 School.is_active.is_(True), SchoolDevice.role == 'primary',
                 SchoolDevice.state == 'active', SchoolDevice.school_id == SchoolEndpoint.school_id,
                 SchoolDevice.generation == SchoolEndpoint.generation).limit(2).all()
