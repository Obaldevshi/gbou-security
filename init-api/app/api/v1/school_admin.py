from typing import Annotated

from datetime import datetime

from fastapi import APIRouter, Depends, Query, Response, status

from app.core.dependencies import (
    AuditLogServiceDep,
    ReportServiceDep,
    SchoolClassAdminServiceDep,
    SchoolBuildingServiceDep,
    StudentAdminServiceDep,
    TeacherAdminServiceDep,
    GuardAdminServiceDep,
    ExitRequestServiceDep,
    require_roles,
)
from app.schemas.school_building import (
    SchoolBuildingCreate,
    SchoolBuildingDeleteEnvelope,
    SchoolBuildingEnvelope,
    SchoolBuildingListEnvelope,
    SchoolBuildingResponse,
    SchoolBuildingStatusUpdate,
    SchoolBuildingUpdate,
)
from app.schemas.audit_log import AuditLogEnvelope
from app.schemas.teacher_admin import (
    TeacherAdminResponse,
    TeacherCreate,
    TeacherDeleteEnvelope,
    TeacherEnvelope,
    TeacherImportEnvelope,
    TeacherImportRequest,
    TeacherListEnvelope,
    TeacherStatusUpdate,
    TeacherUpdate,
)
from app.models.user import User, UserRole
from app.schemas.guard_admin import (
    GuardAdminResponse,
    GuardCreate,
    GuardDeleteEnvelope,
    GuardEnvelope,
    GuardListEnvelope,
    GuardStatusUpdate,
    GuardUpdate,
)
from app.schemas.exit_request import (
    ExitRequestResponse,
    ExitRequestStatusEnvelope,
    ExitRequestStatusResponse,
    TeacherExitRequestsResponse,
    TeacherExitRequestsSnapshotResponse,
)
from app.schemas.school_class_admin import (
    SchoolClassAdminResponse,
    SchoolClassCreate,
    SchoolClassDeleteEnvelope,
    SchoolClassEnvelope,
    SchoolClassListEnvelope,
    SchoolClassStatusUpdate,
    SchoolClassUpdate,
)
from app.schemas.student_admin import (
    StudentAdminResponse,
    StudentCreate,
    StudentDeleteEnvelope,
    StudentEnvelope,
    StudentImportEnvelope,
    StudentImportRequest,
    StudentListEnvelope,
    StudentStatusUpdate,
    StudentUpdate,
)


router = APIRouter()
SchoolAdminDep = Annotated[User, Depends(require_roles(UserRole.SCHOOL_ADMIN))]


@router.get("/buildings", response_model=SchoolBuildingListEnvelope)
def list_buildings(user: SchoolAdminDep, service: SchoolBuildingServiceDep) -> SchoolBuildingListEnvelope:
    return SchoolBuildingListEnvelope(message="Корпуса получены", data=[SchoolBuildingResponse.model_validate(item) for item in service.list(user.school_id)])


@router.post("/buildings", response_model=SchoolBuildingEnvelope, status_code=status.HTTP_201_CREATED)
def create_building(payload: SchoolBuildingCreate, user: SchoolAdminDep, service: SchoolBuildingServiceDep) -> SchoolBuildingEnvelope:
    return SchoolBuildingEnvelope(message="Корпус создан", data=SchoolBuildingResponse.model_validate(service.create(user.school_id, payload)))


@router.patch("/buildings/{building_id}", response_model=SchoolBuildingEnvelope)
def update_building(building_id: int, payload: SchoolBuildingUpdate, user: SchoolAdminDep, service: SchoolBuildingServiceDep) -> SchoolBuildingEnvelope:
    return SchoolBuildingEnvelope(message="Корпус обновлён", data=SchoolBuildingResponse.model_validate(service.update(user.school_id, building_id, payload)))


@router.patch("/buildings/{building_id}/status", response_model=SchoolBuildingEnvelope)
def set_building_status(building_id: int, payload: SchoolBuildingStatusUpdate, user: SchoolAdminDep, service: SchoolBuildingServiceDep) -> SchoolBuildingEnvelope:
    item = service.set_status(user.school_id, building_id, payload.is_active)
    return SchoolBuildingEnvelope(message="Корпус включён" if item.is_active else "Корпус отключён", data=SchoolBuildingResponse.model_validate(item))


@router.delete("/buildings/{building_id}", response_model=SchoolBuildingDeleteEnvelope)
def delete_building(building_id: int, user: SchoolAdminDep, service: SchoolBuildingServiceDep) -> SchoolBuildingDeleteEnvelope:
    service.delete(user.school_id, building_id)
    return SchoolBuildingDeleteEnvelope(message="Корпус удалён")


@router.get("/reports/requests")
def school_report(
    user: SchoolAdminDep,
    service: ReportServiceDep,
    file_format: str = Query(alias="format"),
    date_from: datetime | None = None,
    date_to: datetime | None = None,
) -> Response:
    resolved = "pdf" if file_format == "pdf" else "xlsx"
    content = service.school_requests(user.school_id, resolved, date_from, date_to)
    media = "application/pdf" if resolved == "pdf" else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return Response(content, media_type=media, headers={"Content-Disposition": f'attachment; filename="school_requests.{resolved}"'})


@router.get("/audit", response_model=AuditLogEnvelope)
def list_school_audit(
    user: SchoolAdminDep,
    service: AuditLogServiceDep,
    page: int = 1,
    page_size: int = 25,
    search: str | None = None,
    method: str | None = None,
) -> AuditLogEnvelope:
    page = max(1, page)
    page_size = min(100, max(1, page_size))
    return AuditLogEnvelope(
        message="Журнал аудита школы получен",
        data=service.list(school_id=user.school_id, page=page, page_size=page_size, search=search, method=method),
    )


@router.get("/classes", response_model=SchoolClassListEnvelope)
def list_classes(user: SchoolAdminDep, service: SchoolClassAdminServiceDep, building_id: int | None = None) -> SchoolClassListEnvelope:
    return SchoolClassListEnvelope(message="Классы получены", data=[SchoolClassAdminResponse.model_validate(item) for item in service.list(user.school_id, building_id)])


@router.post("/classes", response_model=SchoolClassEnvelope, status_code=status.HTTP_201_CREATED)
def create_class(payload: SchoolClassCreate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    return SchoolClassEnvelope(message="Класс создан", data=SchoolClassAdminResponse.model_validate(service.create(user.school_id, payload.building_id, payload.name)))


@router.patch("/classes/{class_id}", response_model=SchoolClassEnvelope)
def update_class(class_id: int, payload: SchoolClassUpdate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    return SchoolClassEnvelope(message="Класс обновлён", data=SchoolClassAdminResponse.model_validate(service.update(user.school_id, class_id, payload.building_id, payload.name)))


@router.patch("/classes/{class_id}/status", response_model=SchoolClassEnvelope)
def set_class_status(class_id: int, payload: SchoolClassStatusUpdate, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassEnvelope:
    school_class = service.set_status(user.school_id, class_id, payload.is_active)
    return SchoolClassEnvelope(message="Класс включён" if school_class.is_active else "Класс отключён", data=SchoolClassAdminResponse.model_validate(school_class))


@router.delete("/classes/{class_id}", response_model=SchoolClassDeleteEnvelope)
def delete_class(class_id: int, user: SchoolAdminDep, service: SchoolClassAdminServiceDep) -> SchoolClassDeleteEnvelope:
    service.delete(user.school_id, class_id)
    return SchoolClassDeleteEnvelope(message="Класс и связанные данные удалены")


@router.get("/students", response_model=StudentListEnvelope)
def list_students(user: SchoolAdminDep, service: StudentAdminServiceDep, class_id: int | None = None, building_id: int | None = None) -> StudentListEnvelope:
    return StudentListEnvelope(message="Ученики получены", data=[StudentAdminResponse.model_validate(item) for item in service.list(user.school_id, class_id, building_id)])


@router.post("/students", response_model=StudentEnvelope, status_code=status.HTTP_201_CREATED)
def create_student(payload: StudentCreate, user: SchoolAdminDep, service: StudentAdminServiceDep) -> StudentEnvelope:
    return StudentEnvelope(message="Ученик создан", data=StudentAdminResponse.model_validate(service.create(user.school_id, payload)))


@router.patch("/students/{student_id}", response_model=StudentEnvelope)
def update_student(student_id: int, payload: StudentUpdate, user: SchoolAdminDep, service: StudentAdminServiceDep) -> StudentEnvelope:
    return StudentEnvelope(message="Ученик обновлён", data=StudentAdminResponse.model_validate(service.update(user.school_id, student_id, payload)))


@router.patch("/students/{student_id}/status", response_model=StudentEnvelope)
def set_student_status(student_id: int, payload: StudentStatusUpdate, user: SchoolAdminDep, service: StudentAdminServiceDep) -> StudentEnvelope:
    student = service.set_status(user.school_id, student_id, payload.is_active)
    return StudentEnvelope(message="Ученик включён" if student.is_active else "Ученик отключён", data=StudentAdminResponse.model_validate(student))


@router.delete("/students/{student_id}", response_model=StudentDeleteEnvelope)
def delete_student(student_id: int, user: SchoolAdminDep, service: StudentAdminServiceDep) -> StudentDeleteEnvelope:
    service.delete(user.school_id, student_id)
    return StudentDeleteEnvelope(message="Ученик и связанные заявки удалены")


@router.post("/students/import", response_model=StudentImportEnvelope)
def import_students(payload: StudentImportRequest, user: SchoolAdminDep, service: StudentAdminServiceDep) -> StudentImportEnvelope:
    result = service.import_text(
        user.school_id,
        payload.building_id,
        payload.text,
        class_id=payload.class_id,
        dry_run=payload.dry_run,
    )
    return StudentImportEnvelope(message="Массовая загрузка завершена", data=result)


@router.get("/teachers", response_model=TeacherListEnvelope)
def list_teachers(user: SchoolAdminDep, service: TeacherAdminServiceDep, building_id: int | None = None) -> TeacherListEnvelope:
    return TeacherListEnvelope(message="Учителя получены", data=[TeacherAdminResponse.model_validate(item) for item in service.list(user.school_id, building_id)])


@router.post("/teachers", response_model=TeacherEnvelope, status_code=status.HTTP_201_CREATED)
def create_teacher(payload: TeacherCreate, user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherEnvelope:
    return TeacherEnvelope(message="Учитель создан", data=TeacherAdminResponse.model_validate(service.create(user.school_id, payload)))


@router.patch("/teachers/{teacher_id}", response_model=TeacherEnvelope)
def update_teacher(teacher_id: int, payload: TeacherUpdate, user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherEnvelope:
    return TeacherEnvelope(message="Учитель обновлён", data=TeacherAdminResponse.model_validate(service.update(user.school_id, teacher_id, payload)))


@router.patch("/teachers/{teacher_id}/status", response_model=TeacherEnvelope)
def set_teacher_status(teacher_id: int, payload: TeacherStatusUpdate, user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherEnvelope:
    teacher = service.set_status(user.school_id, teacher_id, payload.is_active)
    return TeacherEnvelope(message="Учитель включён" if teacher.is_active else "Учитель отключён", data=TeacherAdminResponse.model_validate(teacher))


@router.delete("/teachers/{teacher_id}", response_model=TeacherDeleteEnvelope)
def delete_teacher(teacher_id: int, user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherDeleteEnvelope:
    service.delete(user.school_id, teacher_id)
    return TeacherDeleteEnvelope(message="Учитель и связанные заявки удалены")


@router.post("/teachers/import", response_model=TeacherImportEnvelope)
def import_teachers(payload: TeacherImportRequest, user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherImportEnvelope:
    result = service.import_text(user.school_id, payload.building_id, payload.text, dry_run=payload.dry_run)
    return TeacherImportEnvelope(message="Массовая загрузка завершена", data=result)


@router.get("/guards", response_model=GuardListEnvelope)
def list_guards(user: SchoolAdminDep, service: GuardAdminServiceDep, building_id: int | None = None) -> GuardListEnvelope:
    return GuardListEnvelope(message="Пользователи охраны получены", data=[GuardAdminResponse.model_validate(item) for item in service.list(user.school_id, building_id)])


@router.post("/guards", response_model=GuardEnvelope, status_code=status.HTTP_201_CREATED)
def create_guard(payload: GuardCreate, user: SchoolAdminDep, service: GuardAdminServiceDep) -> GuardEnvelope:
    return GuardEnvelope(message="Пользователь охраны создан", data=GuardAdminResponse.model_validate(service.create(user.school_id, payload)))


@router.patch("/guards/{guard_id}", response_model=GuardEnvelope)
def update_guard(guard_id: int, payload: GuardUpdate, user: SchoolAdminDep, service: GuardAdminServiceDep) -> GuardEnvelope:
    return GuardEnvelope(message="Пользователь охраны обновлён", data=GuardAdminResponse.model_validate(service.update(user.school_id, guard_id, payload)))


@router.patch("/guards/{guard_id}/status", response_model=GuardEnvelope)
def set_guard_status(guard_id: int, payload: GuardStatusUpdate, user: SchoolAdminDep, service: GuardAdminServiceDep) -> GuardEnvelope:
    guard = service.set_status(user.school_id, guard_id, payload.is_active)
    return GuardEnvelope(message="Пользователь охраны включён" if guard.is_active else "Пользователь охраны отключён", data=GuardAdminResponse.model_validate(guard))


@router.delete("/guards/{guard_id}", response_model=GuardDeleteEnvelope)
def delete_guard(guard_id: int, user: SchoolAdminDep, service: GuardAdminServiceDep) -> GuardDeleteEnvelope:
    service.delete(user.school_id, guard_id)
    return GuardDeleteEnvelope(message="Пользователь охраны удалён")


@router.get("/exit-requests", response_model=TeacherExitRequestsResponse)
def get_school_exit_requests(user: SchoolAdminDep, service: ExitRequestServiceDep, building_id: int | None = None) -> TeacherExitRequestsResponse:
    active, history = service.get_school_requests(user.school_id, building_id)
    return TeacherExitRequestsResponse(
        message="Заявки школы получены",
        data=TeacherExitRequestsSnapshotResponse(
            active=[ExitRequestResponse.model_validate(item) for item in active],
            history=[ExitRequestResponse.model_validate(item) for item in history],
        ),
    )


@router.post("/exit-requests/{request_id}/cancel", response_model=ExitRequestStatusEnvelope)
def cancel_school_exit_request(request_id: int, user: SchoolAdminDep, service: ExitRequestServiceDep) -> ExitRequestStatusEnvelope:
    request = service.cancel_by_school_admin(user, request_id)
    return ExitRequestStatusEnvelope(
        message="Заявка отменена",
        data=ExitRequestStatusResponse.model_validate(request),
    )
