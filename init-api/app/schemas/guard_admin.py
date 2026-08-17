from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.utils.validation import validate_password_strength


class GuardCreate(BaseModel):
    building_id: int = Field(gt=0)
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=12, max_length=128)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        return validate_password_strength(value)


class GuardUpdate(BaseModel):
    building_id: int = Field(gt=0)
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str | None = Field(default=None, min_length=12, max_length=128)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None

    @field_validator("password")
    @classmethod
    def validate_optional_password(cls, value: str | None) -> str | None:
        return validate_password_strength(value) if value is not None else None


class GuardStatusUpdate(BaseModel):
    is_active: bool


class GuardAdminResponse(BaseModel):
    id: int
    login: str
    full_name: str
    phone: str | None
    is_active: bool
    building_id: int
    building_name: str
    model_config = ConfigDict(from_attributes=True)


class GuardEnvelope(BaseModel):
    message: str
    data: GuardAdminResponse


class GuardListEnvelope(BaseModel):
    message: str
    data: list[GuardAdminResponse]


class GuardDeleteEnvelope(BaseModel):
    message: str
    data: None = None
