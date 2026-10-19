from pydantic import BaseModel, ConfigDict, Field
from typing import Annotated

Digest = Annotated[str, Field(pattern=r'^[a-f0-9]{64}$')]


class ResolveSchool(BaseModel):
    model_config = ConfigDict(extra='forbid')
    login_digest: Digest


class DirectorySnapshot(BaseModel):
    model_config = ConfigDict(extra='forbid')
    generation: int = Field(ge=1)
    login_digests: list[Digest] = Field(max_length=10000)


class SchoolDestination(BaseModel):
    school_id: int
    origin: str
    building_id: int | None = None
    building_name: str | None = None


class SchoolDestinations(BaseModel):
    choices: list[SchoolDestination]


class SnapshotResult(BaseModel):
    published: int = Field(ge=0)
