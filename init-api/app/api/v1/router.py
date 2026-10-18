from fastapi import APIRouter
from app.config.settings import settings
from . import auth, categories, guard, node, school_admin, system, teacher, user
from . import school_devices
from . import device_pairing

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(user.router, prefix="/users", tags=["users"])
if settings.deployment_mode in {"legacy", "local"}:
    api_router.include_router(categories.router, prefix="/categories", tags=["categories"])
    api_router.include_router(teacher.router, prefix="/teacher", tags=["teacher requests"])
    api_router.include_router(guard.router, prefix="/guard", tags=["guard requests"])
    api_router.include_router(school_admin.router, prefix="/school", tags=["school administration"])
if settings.deployment_mode in {"legacy", "cloud"}:
    api_router.include_router(system.router, prefix="/system", tags=["system administration"])
    api_router.include_router(node.router, prefix="/node", tags=["school node"])
    api_router.include_router(school_devices.system_router, prefix='/system', tags=['school devices'])
    api_router.include_router(school_devices.device_router, prefix='/devices', tags=['device enrollment'])
    api_router.include_router(device_pairing.public, prefix='/devices/pairings', tags=['QR pairing'])
    api_router.include_router(device_pairing.admin, prefix='/device-admin', tags=['device administrators'])
