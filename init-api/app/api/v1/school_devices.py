from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, Header, Response
from app.core.dependencies import DatabaseDep, require_roles
from app.models.user import User, UserRole
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.services.school_device_service import SchoolDeviceService
from app.schemas.school_device import (ActivatePrimary, DeviceEnrollment, DeviceOverviewEnvelope,
                                      EnrollDevice, GatewayManifest, InviteDevice)

system_router = APIRouter()
device_router = APIRouter()
Chief = Annotated[User, Depends(require_roles(UserRole.SUPER_ADMIN))]


def service(db: DatabaseDep):
    return SchoolDeviceService(SchoolDeviceRepository(db))


Service = Annotated[SchoolDeviceService, Depends(service)]


@system_router.get('/schools/{school_id}/devices', response_model=DeviceOverviewEnvelope)
def overview(school_id: int, _: Chief, manager: Service, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    return DeviceOverviewEnvelope(message='Устройства школы', data=manager.overview(school_id))


@system_router.post('/schools/{school_id}/device-invitations')
def invitation(school_id: int, payload: InviteDevice, _: Chief, manager: Service, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    return {'message': 'Приглашение действует 10 минут. Сохраните его сейчас',
            'data': manager.invite(school_id, payload.role)}


@system_router.post('/schools/{school_id}/devices/{device_id}/activate', response_model=DeviceOverviewEnvelope)
def activate(school_id: int, device_id: UUID, payload: ActivatePrimary, _: Chief, manager: Service, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    return DeviceOverviewEnvelope(message='Главное устройство переключено',
                                  data=manager.activate(school_id, device_id, payload))


@system_router.post('/schools/{school_id}/devices/{device_id}/revoke', response_model=DeviceOverviewEnvelope)
def revoke(school_id: int, device_id: UUID, _: Chief, manager: Service):
    return DeviceOverviewEnvelope(message='Подключение терминала отозвано',
                                  data=manager.revoke_terminal(school_id, device_id))


@device_router.post('/enroll', response_model=DeviceEnrollment)
def enroll(payload: EnrollDevice, response: Response, manager: Service):
    response.headers['Cache-Control'] = 'no-store'
    return manager.enroll(payload)


@device_router.post('/heartbeat')
def heartbeat(response: Response, manager: Service,
              token: Annotated[str | None, Header(alias='X-School-Device-Token')] = None):
    response.headers['Cache-Control'] = 'no-store'
    return manager.device_status(token or '')


@device_router.get('/gateway-manifest', response_model=GatewayManifest)
def manifest(response: Response, manager: Service,
             token: Annotated[str | None, Header(alias='X-Gateway-Token')] = None):
    response.headers['Cache-Control'] = 'no-store'
    return manager.gateway_manifest(token or '')
