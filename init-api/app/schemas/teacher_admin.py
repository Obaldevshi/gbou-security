from pydantic import BaseModel, ConfigDict, Field, field_validator


class TeacherCreate(BaseModel):
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=8, max_length=128)
    class_ids: list[int] = Field(min_length=1)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None

    @field_validator("class_ids")
    @classmethod
    def unique_classes(cls, value: list[int]) -> list[int]:
        if any(item <= 0 for item in value):
            raise ValueError("Некорректный класс")
        return list(dict.fromkeys(value))


class TeacherUpdate(BaseModel):
    login: str = Field(min_length=3, max_length=100)
    full_name: str = Field(min_length=3, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    password: str | None = Field(default=None, min_length=8, max_length=128)
    class_ids: list[int] = Field(min_length=1)

    @field_validator("login")
    @classmethod
    def normalize_login(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("full_name", "phone")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None

    @field_validator("class_ids")
    @classmethod
    def unique_classes(cls, value: list[int]) -> list[int]:
        if any(item <= 0 for item in value):
            raise ValueError("Некорректный класс")
        return list(dict.fromkeys(value))


class TeacherStatusUpdate(BaseModel):
    is_active: bool


class TeacherClassResponse(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)


class TeacherAdminResponse(BaseModel):
    id: int
    login: str
    full_name: str
    phone: str | None
    is_active: bool
    classes: list[TeacherClassResponse]

    model_config = ConfigDict(from_attributes=True)


class TeacherEnvelope(BaseModel):
    message: str
    data: TeacherAdminResponse


class TeacherListEnvelope(BaseModel):
    message: str
    data: list[TeacherAdminResponse]


class TeacherDeleteEnvelope(BaseModel):
    message: str
    data: None = None
