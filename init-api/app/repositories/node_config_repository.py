from sqlalchemy.orm import Session

from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.school_node_credential import SchoolNodeCredential
from app.models.user import User, UserRole


class NodeConfigRepository:
    def __init__(self, db: Session):
        self.db = db

    def credential_by_hash(self, token_hash: str) -> SchoolNodeCredential | None:
        return self.db.query(SchoolNodeCredential).filter(
            SchoolNodeCredential.token_hash == token_hash,
            SchoolNodeCredential.is_active.is_(True),
        ).first()

    def school(self, school_id: int) -> School | None:
        return self.db.query(School).filter(School.id == school_id).first()

    def buildings(self, school_id: int) -> list[SchoolBuilding]:
        return self.db.query(SchoolBuilding).filter(SchoolBuilding.school_id == school_id).order_by(SchoolBuilding.id).all()

    def admins(self, school_id: int) -> list[User]:
        return self.db.query(User).filter(
            User.school_id == school_id,
            User.role == UserRole.SCHOOL_ADMIN,
        ).order_by(User.id).all()
