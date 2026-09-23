from datetime import datetime
from typing import Literal

from pydantic import BaseModel, field_validator

from app.schemas.user import CurrentUserResponse


class LoginRequest(BaseModel):
    login: str
    password: str

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not normalized:
            raise ValueError("login is required")
        return normalized

    @field_validator("password")
    @classmethod
    def require_password(cls, value: str) -> str:
        if not value:
            raise ValueError("password is required")
        return value


class TokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"]
    expires_in: int
    user: CurrentUserResponse


class TrustedDeviceCreateRequest(BaseModel):
    device_name: str

    @field_validator("device_name")
    @classmethod
    def normalize_device_name(cls, value: str) -> str:
        normalized = " ".join(value.strip().split())
        if not 2 <= len(normalized) <= 120:
            raise ValueError("device_name must contain 2 to 120 characters")
        return normalized


class TrustedDeviceTokenRequest(BaseModel):
    refresh_token: str

    @field_validator("refresh_token")
    @classmethod
    def require_refresh_token(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 40 or len(normalized) > 256:
            raise ValueError("invalid refresh token")
        return normalized


class TrustedDeviceResponse(BaseModel):
    id: int
    name: str
    expires_at: datetime
    last_used_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class TrustedDeviceCreatedResponse(TrustedDeviceResponse):
    refresh_token: str


class TrustedSessionResponse(TokenResponse):
    refresh_token: str
    trusted_device_id: int
