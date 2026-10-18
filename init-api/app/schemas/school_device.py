import base64
from datetime import datetime
from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator


class InviteDevice(BaseModel):
    role: Literal['primary', 'terminal']


class EnrollDevice(BaseModel):
    invitation: str = Field(min_length=40, max_length=128)
    device_id: UUID
    label: str = Field(min_length=1, max_length=80)
    public_key: str | None = None

    @field_validator('label')
    @classmethod
    def label_text(cls, value):
        value = ' '.join(value.split())
        if not value or any(ord(char) < 32 for char in value):
            raise ValueError('Invalid device label')
        return value

    @field_validator('public_key')
    @classmethod
    def wireguard_key(cls, value):
        if value is not None:
            try:
                decoded = base64.b64decode(value, validate=True)
                if len(decoded) != 32 or not any(decoded) or base64.b64encode(decoded).decode() != value:
                    raise ValueError('Invalid WireGuard public key')
            except Exception as error:
                raise ValueError('Invalid WireGuard public key') from error
        return value


class ActivatePrimary(BaseModel):
    expected_generation: int = Field(ge=0)
    previous_primary_stopped: bool
    database_ready_and_backup_verified: bool


class DeviceView(BaseModel):
    device_id: str
    label: str
    role: str
    state: str
    last_seen_at: datetime | None
    generation: int
    model_config = ConfigDict(from_attributes=True)


class DeviceOverview(BaseModel):
    school_id: int
    hostname: str
    generation: int
    primary_device_id: str | None
    devices: list[DeviceView]


class DeviceEnrollment(BaseModel):
    device_id: str
    school_id: int
    role: str
    state: str
    hostname: str
    token: str
    tunnel_ip: str | None
    gateway_public_key: str | None
    gateway_endpoint: str | None
    gateway_tunnel_ip: str | None


class GatewayRoute(BaseModel):
    school_id: int
    hostname: str
    device_id: str
    public_key: str
    tunnel_ip: str
    generation: int


class GatewayManifest(BaseModel):
    schema_version: Literal[1] = 1
    routes: list[GatewayRoute]


class DeviceOverviewEnvelope(BaseModel):
    message: str
    data: DeviceOverview
