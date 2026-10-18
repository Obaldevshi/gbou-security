from app.core.exceptions import ConflictError, NotFoundError
from app.config.settings import settings
from app.models.school_building import SchoolBuilding
from app.repositories.school_building_repository import SchoolBuildingRepository
from app.schemas.school_building import SchoolBuildingCreate, SchoolBuildingUpdate


class SchoolBuildingService:
    def __init__(self, repository: SchoolBuildingRepository):
        self.repository = repository

    def list(self, school_id: int) -> list[SchoolBuilding]:
        return self.repository.list_for_school(school_id)

    def create(self, school_id: int, payload: SchoolBuildingCreate) -> SchoolBuilding:
        self._require_central_management()
        if not self.repository.school_exists(school_id):
            raise NotFoundError("Школа не найдена", code="school_not_found")
        self._unique(school_id, payload.name)
        building = SchoolBuilding(school_id=school_id, is_active=True, **payload.model_dump())
        self.repository.add(building)
        return self._save(building)

    def update(self, school_id: int, building_id: int, payload: SchoolBuildingUpdate) -> SchoolBuilding:
        self._require_central_management()
        building = self._get(school_id, building_id)
        self._unique(school_id, payload.name, building.id)
        building.name = payload.name
        building.address = payload.address
        return self._save(building)

    def set_status(self, school_id: int, building_id: int, active: bool) -> SchoolBuilding:
        self._require_central_management()
        building = self._get(school_id, building_id)
        building.is_active = active
        return self._save(building)

    def delete(self, school_id: int, building_id: int) -> None:
        self._require_central_management()
        building = self._get(school_id, building_id)
        if self.repository.has_local_node(school_id):
            raise ConflictError(
                "У школы есть локальный узел. Отключите корпус; полное удаление требует проверки локальных классов",
                code="building_has_local_node",
            )
        if self.repository.has_dependencies(building.id):
            raise ConflictError(
                "Корпус используется. Сначала перенесите классы и сотрудников",
                code="school_building_in_use",
            )
        try:
            self.repository.delete(building)
            self.repository.commit()
        except Exception:
            self.repository.rollback()
            raise

    def _get(self, school_id: int, building_id: int) -> SchoolBuilding:
        building = self.repository.get_for_school(building_id, school_id)
        if building is None:
            raise NotFoundError("Корпус не найден", code="school_building_not_found")
        return building

    @staticmethod
    def _require_central_management() -> None:
        if settings.deployment_mode == "local":
            raise ConflictError(
                "Корпуса создаёт главный администратор в центральном кабинете",
                code="building_managed_centrally",
            )

    def _unique(self, school_id: int, name: str, exclude_id: int | None = None) -> None:
        if self.repository.name_exists(school_id, name, exclude_id):
            raise ConflictError("Корпус с таким названием уже существует", code="school_building_exists")

    def _save(self, building: SchoolBuilding) -> SchoolBuilding:
        try:
            self.repository.commit()
            return self.repository.refresh(building)
        except Exception:
            self.repository.rollback()
            raise
