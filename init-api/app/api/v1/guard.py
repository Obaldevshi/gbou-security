from fastapi import APIRouter

from app.constants.messages import ExitRequestMessages
from app.core.dependencies import ExitRequestServiceDep, GuardUserDep
from app.schemas.exit_request import (
    ExitRequestReleasedResponse,
    ExitRequestResponse,
    GuardQueueResponse,
    ReleasedExitRequestResponse,
)


router = APIRouter()


@router.get("/exit-requests", response_model=GuardQueueResponse)
def get_guard_queue(
    service: ExitRequestServiceDep,
    guard: GuardUserDep,
) -> GuardQueueResponse:
    requests = service.get_guard_queue(guard)
    return GuardQueueResponse(
        message=ExitRequestMessages.GUARD_QUEUE_RETRIEVED.value,
        data=[ExitRequestResponse.model_validate(item) for item in requests],
    )


@router.post(
    "/exit-requests/{request_id}/release",
    response_model=ExitRequestReleasedResponse,
)
def release_exit_request(
    request_id: int,
    service: ExitRequestServiceDep,
    guard: GuardUserDep,
) -> ExitRequestReleasedResponse:
    request = service.release(guard, request_id)
    return ExitRequestReleasedResponse(
        message=ExitRequestMessages.RELEASED.value,
        data=ReleasedExitRequestResponse.model_validate(request),
    )
