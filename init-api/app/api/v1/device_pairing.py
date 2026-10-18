from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, Header, Response
from fastapi.security import HTTPAuthorizationCredentials
from app.core.dependencies import DatabaseDep, bearer_scheme
from app.repositories.user_repository import UserRepository
from app.repositories.device_pairing_repository import DevicePairingRepository
from app.schemas.device_pairing import (PairingStart, PairingLogin, PairingApproval,
    PairingSession, PairingPassword, PairingContext, PairingSchool, PairingCreated, PairingPreview, PairingPoll)
from app.models.user import User
from app.schemas.school_device import ActivatePrimary, DeviceOverviewEnvelope
from app.services.device_admin_service import DeviceAdminService
from app.services.device_pairing_service import DevicePairingService


def no_store(response: Response):
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Referrer-Policy'] = 'no-referrer'


public = APIRouter(dependencies=[Depends(no_store)])
admin = APIRouter(dependencies=[Depends(no_store)])


def manager(db: DatabaseDep):
    return DevicePairingService(DevicePairingRepository(db))


Manager = Annotated[DevicePairingService, Depends(manager)]


def actor(db: DatabaseDep, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)]):
    return DeviceAdminService(UserRepository(db)).authenticate(credentials.credentials if credentials else '')


Actor = Annotated[User, Depends(actor)]


@admin.post('/login', response_model=PairingSession)
def login(payload: PairingLogin, db: DatabaseDep):
    return DeviceAdminService(UserRepository(db)).login(payload)


@admin.post('/password', response_model=PairingSession)
def password(payload: PairingPassword, db: DatabaseDep,
             credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)]):
    return DeviceAdminService(UserRepository(db)).change_password(credentials.credentials if credentials else '', payload)


@admin.get('/context', response_model=PairingContext)
def context(user: Actor, service: Manager):
    return service.context(user)


@admin.get('/schools/{school_id}', response_model=PairingSchool)
def school(school_id: int, user: Actor, service: Manager):
    return service.school_context(user, school_id)


@admin.post('/pairings/{request_id}/inspect', response_model=PairingPreview)
def inspect(request_id: UUID, user: Actor, service: Manager):
    return service.preview(request_id)


@admin.post('/pairings/{request_id}/approve', response_model=PairingSchool)
def approve(request_id: UUID, payload: PairingApproval, user: Actor, service: Manager):
    return service.approve(user, request_id, payload)


@admin.post('/schools/{school_id}/devices/{device_id}/activate', response_model=DeviceOverviewEnvelope)
def activate(school_id: int, device_id: UUID, payload: ActivatePrimary, user: Actor, service: Manager):
    service.require_owner(user, school_id)
    return DeviceOverviewEnvelope(message='Главное устройство переключено', data=service.activate(school_id, device_id, payload))


@admin.post('/schools/{school_id}/devices/{device_id}/revoke', response_model=DeviceOverviewEnvelope)
def revoke(school_id: int, device_id: UUID, user: Actor, service: Manager):
    service.require_owner(user, school_id)
    return DeviceOverviewEnvelope(message='Терминал отключён', data=service.revoke_terminal(school_id, device_id))


@public.post('', response_model=PairingCreated)
def start(payload: PairingStart, service: Manager):
    return service.start(payload)


@public.post('/{request_id}/poll', response_model=PairingPoll, response_model_exclude_none=True)
def poll(request_id: UUID, service: Manager, token: Annotated[str | None, Header(alias='X-Pairing-Token')] = None):
    return service.poll(request_id, token or '')


@public.post('/{request_id}/complete', response_model=PairingPoll, response_model_exclude_none=True)
def complete(request_id: UUID, service: Manager, token: Annotated[str | None, Header(alias='X-Pairing-Token')] = None):
    return service.poll(request_id, token or '', complete=True)


@public.get('/{request_id}/qr.svg')
def qr(request_id: UUID, service: Manager):
    service.preview(request_id)
    from reportlab.graphics.barcode.qr import QrCodeWidget
    from reportlab.graphics.shapes import Drawing
    from reportlab.graphics import renderSVG
    widget = QrCodeWidget('https://gbousecurity.ru/#/connect/' + str(request_id))
    x1, y1, x2, y2 = widget.getBounds()
    drawing = Drawing(300, 300, transform=[300 / (x2-x1), 0, 0, 300 / (y2-y1), 0, 0])
    drawing.add(widget)
    return Response(renderSVG.drawToString(drawing), media_type='image/svg+xml',
                    headers={'Cache-Control': 'no-store', 'Content-Security-Policy': "default-src 'none'; sandbox",
                             'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff'})
