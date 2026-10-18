from typing import Literal
from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from app.utils.validation import validate_password_strength
from .school_device import EnrollDevice, DeviceEnrollment, DeviceOverview


class PairingStart(BaseModel):
    device_id: UUID
    label: str = Field(min_length=1, max_length=80)
    public_key: str
    poll_token: str = Field(min_length=40, max_length=128, pattern=r'^[A-Za-z0-9_-]+$')

    @field_validator('public_key')
    @classmethod
    def valid_key(cls, value):
        return EnrollDevice.wireguard_key(value)

    @field_validator('label')
    @classmethod
    def valid_label(cls, value):
        return EnrollDevice.label_text(value)

    def validated_device(self):
        # Reuse the canonical label and WireGuard validators.
        return EnrollDevice(device_id=self.device_id, label=self.label,
                            public_key=self.public_key, invitation='x' * 48)


class PairingApproval(BaseModel):
    school_id: int = Field(gt=0)
    building_id: int = Field(gt=0)
    role: Literal['primary', 'terminal']
    code: str = Field(pattern=r'^[0-9]{6}$', min_length=6, max_length=6)


class PairingLogin(BaseModel):
    login: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=1, max_length=72)


class PairingSession(BaseModel):
    access_token: str
    expires_in: int
    password_change_required: bool = False


class PairingPassword(BaseModel):
    new_password: str = Field(min_length=8, max_length=72)

    @field_validator('new_password')
    @classmethod
    def strength(cls, value):
        if len(value.encode('utf-8')) > 72:
            raise ValueError('Пароль должен занимать не более 72 байт UTF-8')
        return validate_password_strength(value)


class PairingChoice(BaseModel):
    id: int
    name: str


class PairingContext(BaseModel):
    schools: list[PairingChoice]


class PairingSchool(BaseModel):
    overview: DeviceOverview
    buildings: list[PairingChoice]


class PairingCreated(BaseModel):
    request_id: str
    verification_code: str
    expires_at: str
    qr_url: str


class PairingPreview(BaseModel):
    request_id: str
    label: str
    fingerprint: str
    expires_at: str


class PairingPoll(BaseModel):
    state: Literal['waiting', 'approved', 'completed']
    enrollment: DeviceEnrollment | None = None
