from fastapi import APIRouter, status

from app.constants.messages import AuthMessages
from app.core.dependencies import AuthServiceDep
from app.core.responses import SuccessResponse
from app.schemas.auth import LoginRequest


router = APIRouter()


@router.post("/login", status_code=status.HTTP_200_OK)
def login(
    auth_service: AuthServiceDep,
    login_data: LoginRequest,
) -> SuccessResponse:
    token = auth_service.authenticate_user(login_data)
    return SuccessResponse(message=AuthMessages.LOGIN_SUCCESS.value, data=token)
