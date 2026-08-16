from fastapi import APIRouter, status

from app.constants.messages import UserMessages
from app.core.dependencies import CurrentUserDep, UserServiceDep
from app.core.responses import SuccessResponse
from app.schemas.user import ChangePasswordRequest, CurrentUserResponse


router = APIRouter()


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
