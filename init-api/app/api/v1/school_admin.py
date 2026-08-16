from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.dependencies import SchoolClassAdminServiceDep, require_roles
from app.models.user import User, UserRole
from app.schemas.school_class_admin import (
    SchoolClassAdminResponse,
    SchoolClassCreate,
    SchoolClassDeleteEnvelope,
    SchoolClassEnvelope,
    SchoolClassListEnvelope,
    SchoolClassStatusUpdate,
    SchoolClassUpdate,
)


router = APIRouter()
SchoolAdminDep = Annotated[User, Depends(require_roles(UserRole.SCHOOL_ADMIN))]


@router.get("/classes", response_model=SchoolClassListEnvelope)
def list_classes(user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassListEnvelope:
    return SchoolClassListEnvelope(message="Классы получены", data=[SchoolClassAdminResponse.model_validate(item) for item in service.list(user.school_id)])


@router.post("/classes", response_model=SchoolClassEnvelope, status_code=status.HTTP_201_CREATED)
def create_class(payload: SchoolClassCreate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    return SchoolClassEnvelope(message="Класс создан", data=SchoolClassAdminResponse.model_validate(service.create(user.school_id, payload.name)))


@router.patch("/classes/{class_id}", response_model=SchoolClassEnvelope)
def update_class(class_id: int, payload: SchoolClassUpdate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    return SchoolClassEnvelope(message="Класс обновлён", data=SchoolClassAdminResponse.model_validate(service.update(user.school_id, class_id, payload.name)))


@router.patch("/classes/{class_id}/status", response_model=SchoolClassEnvelope)
def set_class_status(class_id: int, payload: SchoolClassStatusUpdate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    school_class = service.set_status(user.school_id, class_id, payload.is_active)
    return SchoolClassEnvelope(message="Класс включён" if school_class.is_active else "Класс отключён", data=SchoolClassAdminResponse.model_validate(school_class))


@router.delete("/classes/{class_id}", response_model=SchoolClassDeleteEnvelope)
def delete_class(class_id: int, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassDeleteEnvelope:
    service.delete(user.school_id, class_id)
    return SchoolClassDeleteEnvelope(message="Класс и связанные данные удалены")
