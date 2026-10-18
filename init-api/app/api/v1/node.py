from typing import Annotated

from fastapi import APIRouter, Depends, Header, Response

from app.core.dependencies import DatabaseDep
from app.repositories.node_config_repository import NodeConfigRepository
from app.schemas.node_config import NodeConfigEnvelope
from app.services.node_config_service import NodeConfigService

router = APIRouter()


def get_node_config_service(db: DatabaseDep) -> NodeConfigService:
    return NodeConfigService(NodeConfigRepository(db))


@router.get("/config", response_model=NodeConfigEnvelope)
def get_node_config(
    response: Response,
    service: Annotated[NodeConfigService, Depends(get_node_config_service)],
    token: Annotated[str | None, Header(alias="X-School-Node-Token")] = None,
) -> NodeConfigEnvelope:
    response.headers["Cache-Control"] = "no-store"
    return NodeConfigEnvelope(message="Настройки школы получены", data=service.snapshot(token or ""))
