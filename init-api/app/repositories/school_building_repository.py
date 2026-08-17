from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.exit_request import ExitRequest, SchoolClass
from app.models.school_building import SchoolBuilding
from app.models.user import User


class SchoolBuildingRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_school(self, school_id: int) -> list[SchoolBuilding]:
        return self.db.query(SchoolBuilding).filter(
            SchoolBuilding.school_id == school_id
        ).order_by(SchoolBuilding.name.asc()).all()

    def get_for_school(self, building_id: int, school_id: int) -> SchoolBuilding | None:
        return self.db.query(SchoolBuilding).filter(
            SchoolBuilding.id == building_id,
            SchoolBuilding.school_id == school_id,
        ).first()

    def name_exists(self, school_id: int, name: str, exclude_id: int | None = None) -> bool:
        query = self.db.query(SchoolBuilding.id).filter(
            SchoolBuilding.school_id == school_id,
            func.lower(SchoolBuilding.name) == name.lower(),
        )
        if exclude_id is not None:
            query = query.filter(SchoolBuilding.id != exclude_id)
        return query.first() is not None

    def has_dependencies(self, building_id: int) -> bool:
        return any((
            self.db.query(SchoolClass.id).filter(SchoolClass.building_id == building_id).first(),
            self.db.query(User.id).filter(User.building_id == building_id).first(),
            self.db.query(ExitRequest.id).filter(ExitRequest.building_id == building_id).first(),
        ))

    def add(self, building: SchoolBuilding) -> None:
        self.db.add(building)

    def delete(self, building: SchoolBuilding) -> None:
        self.db.delete(building)

    def commit(self) -> None:
        self.db.commit()

    def rollback(self) -> None:
        self.db.rollback()

    def refresh(self, building: SchoolBuilding) -> SchoolBuilding:
        self.db.refresh(building)
        return building
