from pydantic import BaseModel, ConfigDict, Field, field_validator


class StudentCreate(BaseModel):
    class_id: int = Field(gt=0)
    last_name: str = Field(min_length=1, max_length=100)
    first_name: str = Field(min_length=1, max_length=100)
    middle_name: str | None = Field(default=None, max_length=100)

    @field_validator("last_name", "first_name", "middle_name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str | None:
        return " ".join(value.strip().split()) if value else None


class StudentUpdate(StudentCreate):
    pass


class StudentStatusUpdate(BaseModel):
    is_active: bool


class StudentAdminResponse(BaseModel):
    id: int
    class_id: int
    full_name: str
    last_name: str
    first_name: str
    middle_name: str | None
    is_active: bool
    class_name: str

    model_config = ConfigDict(from_attributes=True)


class StudentEnvelope(BaseModel):
    message: str
    data: StudentAdminResponse


class StudentListEnvelope(BaseModel):
    message: str
    data: list[StudentAdminResponse]


class StudentDeleteEnvelope(BaseModel):
    message: str
    data: None = None


class StudentImportRequest(BaseModel):
    text: str = Field(min_length=1, max_length=500_000)


class StudentImportRowError(BaseModel):
    line: int
    message: str


class StudentImportResult(BaseModel):
    created_count: int
    errors: list[StudentImportRowError]


class StudentImportEnvelope(BaseModel):
    message: str
    data: StudentImportResult
