from pydantic import BaseModel

from app.models.user import UserRole


class CurrentUserResponse(BaseModel):
    id: int
    login: str
    full_name: str
    phone: str | None
    role: UserRole
    school_id: int | None
    is_active: bool

    model_config = {"from_attributes": True}
