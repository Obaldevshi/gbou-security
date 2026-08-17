from pydantic import BaseModel, ConfigDict, Field, field_validator


class SchoolClassCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    building_id: int = Field(gt=0)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        return " ".join(value.strip().split())


class SchoolClassUpdate(SchoolClassCreate):
    pass


class SchoolClassStatusUpdate(BaseModel):
    is_active: bool


class SchoolClassAdminResponse(BaseModel):
    id: int
    name: str
    building_id: int
    building_name: str
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class SchoolClassEnvelope(BaseModel):
    message: str
    data: SchoolClassAdminResponse


class SchoolClassListEnvelope(BaseModel):
    message: str
    data: list[SchoolClassAdminResponse]


class SchoolClassDeleteEnvelope(BaseModel):
    message: str
    data: None = None
