from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from app.constants.messages import SchoolMessages
from app.core.dependencies import (
    AuditLogServiceDep,
    ReportServiceDep,
    SchoolAdminServiceDep,
    SchoolServiceDep,
    require_roles,
)
from app.schemas.audit_log import AuditLogEnvelope
from app.core.middleware import AppMetrics
from app.models.user import User, UserRole
from app.schemas.school import (
    SchoolCreate,
    SchoolDeleteEnvelope,
    SchoolEnvelope,
    SchoolListEnvelope,
    SchoolResponse,
    SchoolStatusUpdate,
    SystemStatsEnvelope,
    SystemStatsResponse,
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


@router.get("/monitoring")
def monitoring(_: SuperAdminDep) -> dict:
    return {"message": "Метрики приложения получены", "data": AppMetrics.snapshot()}


@router.get("/reports/overview")
def system_report(_: SuperAdminDep, service: ReportServiceDep, file_format: str = Query(alias="format")) -> Response:
    resolved = "pdf" if file_format == "pdf" else "xlsx"
    content = service.system_overview(resolved)
    media = "application/pdf" if resolved == "pdf" else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return Response(content, media_type=media, headers={"Content-Disposition": f'attachment; filename="system_report.{resolved}"'})


@router.get("/audit", response_model=AuditLogEnvelope)
def list_audit(
    _: SuperAdminDep,
    service: AuditLogServiceDep,
    page: int = 1,
    page_size: int = 25,
    search: str | None = None,
    method: str | None = None,
) -> AuditLogEnvelope:
    page = max(1, page)
    page_size = min(100, max(1, page_size))
    return AuditLogEnvelope(
        message="Журнал аудита получен",
        data=service.list(school_id=None, page=page, page_size=page_size, search=search, method=method),
    )


@router.get("/stats", response_model=SystemStatsEnvelope)
def get_system_stats(
    _: SuperAdminDep,
    service: SchoolServiceDep,
) -> SystemStatsEnvelope:
    return SystemStatsEnvelope(
        message="Статистика системы получена",
        data=SystemStatsResponse(**service.get_system_stats()),
    )


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
