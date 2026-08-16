from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.user import UserRole


class CurrentUserResponse(BaseModel):
    id: int
    login: str
    full_name: str
    phone: str | None
    role: UserRole
    school_id: int | None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)

    model_config = ConfigDict(extra="forbid")
