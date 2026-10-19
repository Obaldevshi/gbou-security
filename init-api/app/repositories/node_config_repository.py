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
            primary = SchoolDeviceRepository(self.db).current_primary_by_token(
                token_hash, building_scoped=settings.building_nodes_enabled)
            if primary is not None:
                return primary
        legacy = self.db.query(SchoolNodeCredential).filter(
            SchoolNodeCredential.token_hash == token_hash,
            SchoolNodeCredential.is_active.is_(True),
        ).first()
        if legacy is not None and settings.school_devices_enabled:
            if settings.building_nodes_enabled:
                # Unscoped school credentials must never fetch another building.
                return None
            endpoint = SchoolDeviceRepository(self.db).endpoint(legacy.school_id)
            if endpoint is not None and endpoint.primary_device_id is not None:
                return None
        return legacy

    def school(self, school_id: int) -> School | None:
        return self.db.query(School).filter(School.id == school_id).first()

    def buildings(self, school_id: int, building_id: int | None = None) -> list[SchoolBuilding]:
        query = self.db.query(SchoolBuilding).filter(SchoolBuilding.school_id == school_id)
        if building_id is not None:
            query = query.filter(SchoolBuilding.id == building_id)
        return query.order_by(SchoolBuilding.id).all()

    def admins(self, school_id: int, building_id: int | None = None) -> list[User]:
        query = self.db.query(User).filter(
            User.school_id == school_id,
            User.role == UserRole.SCHOOL_ADMIN,
        )
        if building_id is not None:
            query = query.filter((User.building_id == building_id) | User.building_id.is_(None))
        return query.order_by(User.id).all()
