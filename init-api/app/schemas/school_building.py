from pydantic import BaseModel, ConfigDict, Field, field_validator


class SchoolBuildingBase(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    address: str = Field(min_length=3, max_length=255)

    @field_validator("name", "address")
    @classmethod
    def normalize_text(cls, value: str) -> str:
        return " ".join(value.strip().split())


class SchoolBuildingCreate(SchoolBuildingBase):
    pass


class SchoolBuildingUpdate(SchoolBuildingBase):
    pass


class SchoolBuildingStatusUpdate(BaseModel):
    is_active: bool


class SchoolBuildingResponse(SchoolBuildingBase):
    id: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)


class SchoolBuildingEnvelope(BaseModel):
    message: str
    data: SchoolBuildingResponse


class SchoolBuildingListEnvelope(BaseModel):
    message: str
    data: list[SchoolBuildingResponse]


class SchoolBuildingDeleteEnvelope(BaseModel):
    message: str
    data: None = None
