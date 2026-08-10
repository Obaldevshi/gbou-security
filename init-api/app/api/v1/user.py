from fastapi import APIRouter, status

from app.constants.messages import UserMessages
from app.core.dependencies import CurrentUserDep
from app.core.responses import SuccessResponse
from app.schemas.user import CurrentUserResponse


router = APIRouter()


@router.get("/", status_code=status.HTTP_200_OK)
def get_user(current_user: CurrentUserDep) -> SuccessResponse:
    user_response = CurrentUserResponse.model_validate(current_user)
    return SuccessResponse(message=UserMessages.RETRIEVED_SUCCESS.value, data=user_response)
