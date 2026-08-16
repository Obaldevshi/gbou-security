from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.dependencies import (
    SchoolClassAdminServiceDep,
    StudentAdminServiceDep,
    TeacherAdminServiceDep,
    require_roles,
)
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


@router.get("/students", response_model=StudentListEnvelope)
def list_students(user: SchoolAdminDep, service: StudentAdminServiceDep, class_id: int | None = None) -> StudentListEnvelope:
    return StudentListEnvelope(message="Ученики получены", data=[StudentAdminResponse.model_validate(item) for item in service.list(user.school_id, class_id)])


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
    result = service.import_text(user.school_id, payload.text)
    return StudentImportEnvelope(message="Массовая загрузка завершена", data=result)


@router.get("/teachers", response_model=TeacherListEnvelope)
def list_teachers(user: SchoolAdminDep, service: TeacherAdminServiceDep) -> TeacherListEnvelope:
    return TeacherListEnvelope(message="Учителя получены", data=[TeacherAdminResponse.model_validate(item) for item in service.list(user.school_id)])


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
    result = service.import_text(user.school_id, payload.text)
    return TeacherImportEnvelope(message="Массовая загрузка завершена", data=result)
