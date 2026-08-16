import asyncio
import json

from fastapi import APIRouter, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func

from app.constants.messages import UserMessages
from app.core.dependencies import CurrentUserDep, UserServiceDep
from app.core.responses import SuccessResponse
from app.schemas.user import ChangePasswordRequest, CurrentUserResponse
from app.config.database import SessionLocal
from app.core.exceptions import ForbiddenError
from app.models.exit_request import ExitRequest
from app.models.user import UserRole


router = APIRouter()


@router.get("/request-events")
def request_events(current_user: CurrentUserDep) -> StreamingResponse:
    if current_user.must_change_password:
        raise ForbiddenError("Сначала смените временный пароль", code="password_change_required")
    user_id = current_user.id
    school_id = current_user.school_id
    role = current_user.role

    async def stream():
        previous = None
        heartbeat = 0
        while True:
            db = SessionLocal()
            try:
                query = db.query(func.max(ExitRequest.updated_at), func.count(ExitRequest.id))
                if role == UserRole.TEACHER:
                    query = query.filter(ExitRequest.teacher_id == user_id)
                elif school_id is not None:
                    query = query.filter(ExitRequest.school_id == school_id)
                version = query.one()
                marker = f"{version[0].isoformat() if version[0] else ''}:{version[1]}"
            finally:
                db.close()
            if marker != previous:
                previous = marker
                yield f"event: requests\ndata: {json.dumps({'version': marker})}\n\n"
            heartbeat += 1
            if heartbeat >= 20:
                heartbeat = 0
                yield ": heartbeat\n\n"
            await asyncio.sleep(1)

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/", status_code=status.HTTP_200_OK)
def get_user(current_user: CurrentUserDep) -> SuccessResponse:
    user_response = CurrentUserResponse.model_validate(current_user)
    return SuccessResponse(message=UserMessages.RETRIEVED_SUCCESS.value, data=user_response)


@router.post("/change-password", status_code=status.HTTP_200_OK)
def change_password(
    payload: ChangePasswordRequest,
    current_user: CurrentUserDep,
    service: UserServiceDep,
) -> SuccessResponse:
    service.change_password(
        current_user,
        payload.current_password,
        payload.new_password,
    )
    return SuccessResponse(message="Пароль изменён")
