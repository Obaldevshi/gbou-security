from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.constants.messages import SchoolMessages
from app.core.dependencies import (
    SchoolAdminServiceDep,
    SchoolServiceDep,
    require_roles,
)
from app.models.user import User, UserRole
from app.schemas.school import (
    SchoolCreate,
    SchoolDeleteEnvelope,
    SchoolEnvelope,
    SchoolListEnvelope,
    SchoolResponse,
    SchoolStatusUpdate,
    SchoolUpdate,
)
from app.schemas.school_admin import (
    SchoolAdminCreate,
    SchoolAdminDeleteEnvelope,
    SchoolAdminEnvelope,
    SchoolAdminListEnvelope,
    SchoolAdminResponse,
    SchoolAdminUpdate,
    UserStatusUpdate,
)


router = APIRouter()
SuperAdminDep = Annotated[User, Depends(require_roles(UserRole.SUPER_ADMIN))]


@router.get("/schools", response_model=SchoolListEnvelope)
def list_schools(
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SchoolListEnvelope:
    return SchoolListEnvelope(
        message=SchoolMessages.RETRIEVED.value,
        data=[
            SchoolResponse.model_validate(school)
            for school in service.list_schools()
        ],
    )


@router.post(
    "/schools",
    response_model=SchoolEnvelope,
    status_code=status.HTTP_201_CREATED,
)
def create_school(
    payload: SchoolCreate,
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SchoolEnvelope:
    school = service.create_school(payload)
    return SchoolEnvelope(
        message=SchoolMessages.CREATED.value,
        data=SchoolResponse.model_validate(school),
    )


@router.patch("/schools/{school_id}", response_model=SchoolEnvelope)
def update_school(
    school_id: int,
    payload: SchoolUpdate,
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SchoolEnvelope:
    school = service.update_school(school_id, payload)
    return SchoolEnvelope(
        message=SchoolMessages.UPDATED.value,
        data=SchoolResponse.model_validate(school),
    )


@router.patch("/schools/{school_id}/status", response_model=SchoolEnvelope)
def set_school_status(
    school_id: int,
    payload: SchoolStatusUpdate,
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SchoolEnvelope:
    school = service.set_school_status(school_id, payload)
    return SchoolEnvelope(
        message=(
            SchoolMessages.ENABLED.value
            if school.is_active
            else SchoolMessages.DISABLED.value
        ),
        data=SchoolResponse.model_validate(school),
    )


@router.delete("/schools/{school_id}", response_model=SchoolDeleteEnvelope)
def delete_school(
    school_id: int,
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SchoolDeleteEnvelope:
    service.delete_school(school_id)
    return SchoolDeleteEnvelope(message=SchoolMessages.DELETED.value)


@router.get("/school-admins", response_model=SchoolAdminListEnvelope)
def list_school_admins(
    _: SuperAdminDep,
    service: SchoolAdminServiceDep,
) -> SchoolAdminListEnvelope:
    return SchoolAdminListEnvelope(
        message="Администраторы школ получены",
        data=[SchoolAdminResponse.model_validate(user) for user in service.list()],
    )


@router.post(
    "/school-admins",
    response_model=SchoolAdminEnvelope,
    status_code=status.HTTP_201_CREATED,
)
def create_school_admin(
    payload: SchoolAdminCreate,
    _: SuperAdminDep,
    service: SchoolAdminServiceDep,
) -> SchoolAdminEnvelope:
    return SchoolAdminEnvelope(
        message="Администратор школы создан",
        data=SchoolAdminResponse.model_validate(service.create(payload)),
    )


@router.patch("/school-admins/{user_id}", response_model=SchoolAdminEnvelope)
def update_school_admin(
    user_id: int,
    payload: SchoolAdminUpdate,
    _: SuperAdminDep,
    service: SchoolAdminServiceDep,
) -> SchoolAdminEnvelope:
    return SchoolAdminEnvelope(
        message="Администратор школы обновлён",
        data=SchoolAdminResponse.model_validate(service.update(user_id, payload)),
    )


@router.patch(
    "/school-admins/{user_id}/status",
    response_model=SchoolAdminEnvelope,
)
def set_school_admin_status(
    user_id: int,
    payload: UserStatusUpdate,
    _: SuperAdminDep,
    service: SchoolAdminServiceDep,
) -> SchoolAdminEnvelope:
    user = service.set_status(user_id, payload.is_active)
    return SchoolAdminEnvelope(
        message="Учётная запись включена" if user.is_active else "Учётная запись отключена",
        data=SchoolAdminResponse.model_validate(user),
    )


@router.delete(
    "/school-admins/{user_id}",
    response_model=SchoolAdminDeleteEnvelope,
)
def delete_school_admin(
    user_id: int,
    _: SuperAdminDep,
    service: SchoolAdminServiceDep,
) -> SchoolAdminDeleteEnvelope:
    service.delete(user_id)
    return SchoolAdminDeleteEnvelope(message="Администратор школы удалён")
