from fastapi import APIRouter, status

from app.constants.messages import ExitRequestMessages
from app.core.dependencies import ExitRequestServiceDep, TeacherUserDep
from app.schemas.exit_request import (
    ClassStudentsResponse,
    ExitRequestCreate,
    ExitRequestCreatedResponse,
    ExitRequestResponse,
    StudentResponse,
    TeacherClassesResponse,
    TeacherClassResponse,
    TeacherExitRequestsResponse,
    TeacherExitRequestsSnapshotResponse,
)
from app.schemas.student_admin import (
    StudentAdminResponse,
    StudentCreate,
    StudentDeleteEnvelope,
    StudentEnvelope,
    StudentListEnvelope,
    StudentStatusUpdate,
)


router = APIRouter()


@router.get("/exit-requests", response_model=TeacherExitRequestsResponse)
def get_teacher_exit_requests(
    service: ExitRequestServiceDep,
    teacher: TeacherUserDep,
) -> TeacherExitRequestsResponse:
    active, history = service.get_teacher_requests(teacher)
    return TeacherExitRequestsResponse(
        message=ExitRequestMessages.TEACHER_REQUESTS_RETRIEVED.value,
        data=TeacherExitRequestsSnapshotResponse(
            active=[ExitRequestResponse.model_validate(item) for item in active],
            history=[ExitRequestResponse.model_validate(item) for item in history],
        ),
    )


@router.get("/classes", response_model=TeacherClassesResponse)
def get_teacher_classes(
    service: ExitRequestServiceDep,
    teacher: TeacherUserDep,
) -> TeacherClassesResponse:
    classes = service.get_teacher_classes(teacher)
    return TeacherClassesResponse(
        message=ExitRequestMessages.CLASSES_RETRIEVED.value,
        data=[TeacherClassResponse.model_validate(item) for item in classes],
    )


@router.get(
    "/classes/{class_id}/students",
    response_model=ClassStudentsResponse,
)
def get_class_students(
    class_id: int,
    service: ExitRequestServiceDep,
    teacher: TeacherUserDep,
) -> ClassStudentsResponse:
    students = service.get_class_students(teacher, class_id)
    return ClassStudentsResponse(
        message=ExitRequestMessages.STUDENTS_RETRIEVED.value,
        data=[StudentResponse.model_validate(item) for item in students],
    )


@router.post(
    "/exit-requests",
    response_model=ExitRequestCreatedResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_exit_request(
    request_data: ExitRequestCreate,
    service: ExitRequestServiceDep,
    teacher: TeacherUserDep,
) -> ExitRequestCreatedResponse:
    request = service.create(teacher, request_data)
    return ExitRequestCreatedResponse(
        message=ExitRequestMessages.CREATED.value,
        data=ExitRequestResponse.model_validate(request),
    )


@router.get("/students", response_model=StudentListEnvelope)
def get_teacher_students(service: ExitRequestServiceDep, teacher: TeacherUserDep) -> StudentListEnvelope:
    return StudentListEnvelope(message="Ученики получены", data=[StudentAdminResponse.model_validate(item) for item in service.get_teacher_students(teacher)])


@router.post("/students", response_model=StudentEnvelope, status_code=status.HTTP_201_CREATED)
def create_teacher_student(payload: StudentCreate, service: ExitRequestServiceDep, teacher: TeacherUserDep) -> StudentEnvelope:
    return StudentEnvelope(message="Ученик добавлен", data=StudentAdminResponse.model_validate(service.create_teacher_student(teacher, payload)))


@router.patch("/students/{student_id}/status", response_model=StudentEnvelope)
def set_teacher_student_status(student_id: int, payload: StudentStatusUpdate, service: ExitRequestServiceDep, teacher: TeacherUserDep) -> StudentEnvelope:
    student = service.set_teacher_student_status(teacher, student_id, payload.is_active)
    return StudentEnvelope(message="Ученик включён" if student.is_active else "Ученик отключён", data=StudentAdminResponse.model_validate(student))


@router.delete("/students/{student_id}", response_model=StudentDeleteEnvelope)
def delete_teacher_student(student_id: int, service: ExitRequestServiceDep, teacher: TeacherUserDep) -> StudentDeleteEnvelope:
    service.delete_teacher_student(teacher, student_id)
    return StudentDeleteEnvelope(message="Ученик и связанные заявки удалены")
