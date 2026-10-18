from sqlalchemy.orm import Session

from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_node_credential import SchoolNodeCredential
from app.models.user import User, UserRole
from app.config.settings import settings
from app.repositories.school_device_repository import SchoolDeviceRepository


class NodeConfigRepository:
    def __init__(self, db: Session):
        self.db = db

    def credential_by_hash(self, token_hash: str) -> SchoolNodeCredential | None:
        if settings.school_devices_enabled:
            primary = SchoolDeviceRepository(self.db).current_primary_by_token(token_hash)
            if primary is not None:
                return primary
        legacy = self.db.query(SchoolNodeCredential).filter(
            SchoolNodeCredential.token_hash == token_hash,
            SchoolNodeCredential.is_active.is_(True),
        ).first()
        if legacy is not None and settings.school_devices_enabled:
            endpoint = SchoolDeviceRepository(self.db).endpoint(legacy.school_id)
            if endpoint is not None and endpoint.primary_device_id is not None:
                return None
        return legacy

    def school(self, school_id: int) -> School | None:
        return self.db.query(School).filter(School.id == school_id).first()

    def buildings(self, school_id: int) -> list[SchoolBuilding]:
        return self.db.query(SchoolBuilding).filter(SchoolBuilding.school_id == school_id).order_by(SchoolBuilding.id).all()

    def admins(self, school_id: int) -> list[User]:
        return self.db.query(User).filter(
            User.school_id == school_id,
            User.role == UserRole.SCHOOL_ADMIN,
        ).order_by(User.id).all()
