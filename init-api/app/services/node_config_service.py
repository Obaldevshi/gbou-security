import hashlib

from app.core.exceptions import UnauthorizedError
from app.repositories.node_config_repository import NodeConfigRepository
from app.schemas.node_config import NodeBuilding, NodeConfig, NodeSchool, NodeSchoolAdmin


class NodeConfigService:
    def __init__(self, repository: NodeConfigRepository):
        self.repository = repository

    def snapshot(self, raw_token: str) -> NodeConfig:
        if len(raw_token) < 40 or len(raw_token) > 256:
            raise UnauthorizedError("Недействительный ключ школьного узла", code="node_unauthorized")
        credential = self.repository.credential_by_hash(hashlib.sha256(raw_token.encode()).hexdigest())
        if credential is None:
            raise UnauthorizedError("Недействительный ключ школьного узла", code="node_unauthorized")
        school = self.repository.school(credential.school_id)
        if school is None:
            raise UnauthorizedError("Школа узла не найдена", code="node_school_missing")
        return NodeConfig(
            school=NodeSchool.model_validate(school),
            buildings=[NodeBuilding.model_validate(item) for item in self.repository.buildings(school.id)],
            school_admins=[NodeSchoolAdmin.model_validate(item) for item in self.repository.admins(school.id)],
        )
