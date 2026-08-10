from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.exit_request import ExitReasonType, ExitRequestStatus


class StrictRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class TeacherClassResponse(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)


class StudentResponse(BaseModel):
    id: int
    class_id: int
    first_name: str
    last_name: str
    middle_name: str | None = None
    full_name: str

    model_config = ConfigDict(from_attributes=True)


class ExitRequestCreate(StrictRequestModel):
    class_id: int = Field(gt=0)
    student_id: int = Field(gt=0)
    reason_type: ExitReasonType
    custom_reason: str | None = Field(default=None, max_length=500)
    scheduled_at: datetime


class ExitRequestResponse(BaseModel):
    id: int
    class_id: int
    class_name: str
    student_id: int
    student_full_name: str
    teacher_id: int
    teacher_full_name: str
    reason_type: ExitReasonType
    custom_reason: str | None = None
    scheduled_at: datetime
    status: ExitRequestStatus
    created_at: datetime
    released_at: datetime | None = None
    released_by_id: int | None = None

    model_config = ConfigDict(from_attributes=True)


class TeacherClassesResponse(BaseModel):
    message: str
    data: list[TeacherClassResponse]


class ClassStudentsResponse(BaseModel):
    message: str
    data: list[StudentResponse]


class ExitRequestCreatedResponse(BaseModel):
    message: str
    data: ExitRequestResponse


class GuardQueueResponse(BaseModel):
    message: str
    data: list[ExitRequestResponse]


class ReleasedExitRequestResponse(BaseModel):
    id: int
    status: ExitRequestStatus
    released_at: datetime
    released_by_id: int

    model_config = ConfigDict(from_attributes=True)


class ExitRequestReleasedResponse(BaseModel):
    message: str
    data: ReleasedExitRequestResponse


class TeacherExitRequestsSnapshotResponse(BaseModel):
    active: list[ExitRequestResponse]
    history: list[ExitRequestResponse]


class TeacherExitRequestsResponse(BaseModel):
    message: str
    data: TeacherExitRequestsSnapshotResponse
