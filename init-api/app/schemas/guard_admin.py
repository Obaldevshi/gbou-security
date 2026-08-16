from pydantic import BaseModel, ConfigDict, Field, field_validator


class GuardCreate(BaseModel):
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None


class GuardUpdate(BaseModel):
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str | None = Field(default=None, min_length=8, max_length=128)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None


class GuardStatusUpdate(BaseModel):
    is_active: bool


class GuardAdminResponse(BaseModel):
    id: int
    login: str
    full_name: str
    phone: str | None
    is_active: bool
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
