from typing import Literal
from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from .school_device import EnrollDevice


class AdoptExistingPrimary(BaseModel):
    school_id: int = Field(gt=0)
    building_id: int = Field(gt=0)
    device_id: UUID
    label: str = Field(min_length=1, max_length=80)
    public_key: str
    tunnel_ip: Literal['10.77.203.2']
    hostname: Literal['school-2036.gbousecurity.ru']
    expected_generation: int = Field(ge=0)
    credential_fingerprint: str = Field(pattern=r'^[a-f0-9]{64}$')
    same_writer_verified: bool
    backup_restore_verified: bool

    @field_validator('public_key')
    @classmethod
    def key(cls, value):
        return EnrollDevice.wireguard_key(value)

    @field_validator('label')
    @classmethod
    def label_text(cls, value):
        return EnrollDevice.label_text(value)
