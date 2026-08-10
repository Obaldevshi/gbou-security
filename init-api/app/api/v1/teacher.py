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
