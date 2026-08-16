from pydantic import BaseModel, ConfigDict, Field, field_validator


class SchoolBase(BaseModel):
    full_name: str = Field(min_length=3, max_length=255)
    short_name: str = Field(min_length=2, max_length=100)
    address: str = Field(min_length=3, max_length=255)

    @field_validator("full_name", "short_name", "address")
    @classmethod
    def normalize_text(cls, value: str) -> str:
        return " ".join(value.strip().split())


class SchoolCreate(SchoolBase):
    pass


class SchoolUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=3, max_length=255)
    short_name: str | None = Field(default=None, min_length=2, max_length=100)
    address: str | None = Field(default=None, min_length=3, max_length=255)

    @field_validator("full_name", "short_name", "address")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value is not None else None


class SchoolStatusUpdate(BaseModel):
    is_active: bool


class SchoolResponse(SchoolBase):
    id: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class SchoolEnvelope(BaseModel):
    message: str
    data: SchoolResponse


class SchoolListEnvelope(BaseModel):
    message: str
    data: list[SchoolResponse]


class SchoolDeleteEnvelope(BaseModel):
    message: str
    data: None = None


class SystemStatsResponse(BaseModel):
    schools: int
    active_schools: int
    school_admins: int
    users: int


class SystemStatsEnvelope(BaseModel):
    message: str
    data: SystemStatsResponse
