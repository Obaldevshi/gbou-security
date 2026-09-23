from fastapi import APIRouter, status

from app.constants.messages import AuthMessages
from app.core.dependencies import AuthServiceDep, CurrentUserDep
from app.core.responses import SuccessResponse
from app.schemas.auth import (
    LoginRequest,
    TrustedDeviceCreateRequest,
    TrustedDeviceTokenRequest,
)


router = APIRouter()


@router.post("/login", status_code=status.HTTP_200_OK)
def login(
    auth_service: AuthServiceDep,
    login_data: LoginRequest,
) -> SuccessResponse:
    token = auth_service.authenticate_user(login_data)
    return SuccessResponse(message=AuthMessages.LOGIN_SUCCESS.value, data=token)


@router.post(
    "/trusted-devices",
    status_code=status.HTTP_201_CREATED,
    response_model=SuccessResponse,
)
def create_trusted_device(
    payload: TrustedDeviceCreateRequest,
    current_user: CurrentUserDep,
    auth_service: AuthServiceDep,
) -> SuccessResponse:
    return SuccessResponse(
        message="Доверенное устройство добавлено",
        data=auth_service.create_trusted_device(current_user, payload.device_name),
    )


@router.post(
    "/trusted-devices/refresh",
    status_code=status.HTTP_200_OK,
    response_model=SuccessResponse,
)
def refresh_trusted_device(
    payload: TrustedDeviceTokenRequest,
    auth_service: AuthServiceDep,
) -> SuccessResponse:
    return SuccessResponse(
        message="Сессия обновлена",
        data=auth_service.refresh_trusted_device(payload.refresh_token),
    )


@router.post(
    "/trusted-devices/revoke-token",
    status_code=status.HTTP_200_OK,
    response_model=SuccessResponse,
)
def revoke_trusted_device_token(
    payload: TrustedDeviceTokenRequest,
    auth_service: AuthServiceDep,
) -> SuccessResponse:
    auth_service.revoke_by_token(payload.refresh_token)
    return SuccessResponse(message="Доверенная сессия отозвана")


@router.get("/trusted-devices", response_model=SuccessResponse)
def list_trusted_devices(
    current_user: CurrentUserDep,
    auth_service: AuthServiceDep,
) -> SuccessResponse:
    return SuccessResponse(
        message="Доверенные устройства загружены",
        data=auth_service.list_trusted_devices(current_user),
    )


@router.delete(
    "/trusted-devices/{session_id}",
    status_code=status.HTTP_200_OK,
    response_model=SuccessResponse,
)
def revoke_trusted_device(
    session_id: int,
    current_user: CurrentUserDep,
    auth_service: AuthServiceDep,
) -> SuccessResponse:
    auth_service.revoke_trusted_device(current_user, session_id)
    return SuccessResponse(message="Доверенное устройство отозвано")
