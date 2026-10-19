import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError

from app.config.settings import settings
from app.api.v1.router import api_router
from app.api.health import router as health_router
from app.core.exceptions import BaseError
from app.core.responses import SuccessResponse
from app.core.middleware import RequestLoggingMiddleware
from app.constants.messages import ValidationMessages

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

@asynccontextmanager
async def lifespan(_app):
    if settings.deployment_mode == 'cloud' and settings.building_nodes_enabled:
        from app.config.database import SessionLocal
        from app.repositories.school_device_repository import SchoolDeviceRepository
        with SessionLocal() as db:
            SchoolDeviceRepository(db).validate_building_transition()
    if settings.deployment_mode == 'local' and settings.gbou_building_id is not None:
        from app.config.database import engine
        from app.core.building_scope import validate_building_database
        with engine.connect() as connection:
            validate_building_database(connection, settings.gbou_building_id)
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, debug=settings.debug, lifespan=lifespan)


@app.middleware('http')
async def directory_request_limits(request: Request, call_next):
    if request.url.path.startswith('/api/v1/login-directory/'):
        limit = 2048 if request.url.path.endswith(('/resolve', '/destinations')) else 1048576
        body = bytearray()
        async for chunk in request.stream():
            if len(body) + len(chunk) > limit:
                return JSONResponse(status_code=413, content={'code': 'directory_payload_too_large'},
                                    headers={'Cache-Control': 'no-store'})
            body.extend(chunk)
        request._body = bytes(body)
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        return response
    return await call_next(request)


@app.middleware("http")
async def migration_write_freeze(request: Request, call_next):
    path = request.url.path
    if (
        settings.deployment_mode == "legacy"
        and settings.migration_freeze_writes
        and request.method in {"POST", "PUT", "PATCH", "DELETE"}
        and path.startswith((
            "/api/v1/teacher/", "/api/v1/guard/", "/api/v1/school/",
            "/api/v1/users/", "/api/v1/categories/",
            "/api/v1/auth/trusted-devices",
        ))
    ):
        return JSONResponse(
            status_code=503,
            content={
                "status_code": 503,
                "message": "Школьные изменения временно приостановлены для переноса данных",
                "detail": "Школьные изменения временно приостановлены для переноса данных",
                "code": "school_migration_freeze",
            },
            headers={"Retry-After": "300"},
        )
    return await call_next(request)

app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=settings.effective_cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(BaseError)
async def base_error_handler(_: Request, exc: BaseError):
    return JSONResponse(
        status_code=exc.status_code,
        headers=exc.headers,
        content={
            "status_code": exc.status_code,
            "message": exc.message,
            "detail": exc.message,
            "code": exc.code,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={
            "status_code": 422,
            "message": ValidationMessages.REQUIRED_FIELDS.value,
            "detail": ValidationMessages.REQUIRED_FIELDS.value,
            "code": "validation_error",
        },
    )


@app.get("/")
def read_root():
    return SuccessResponse(
        message="API ГБОУ Безопасность работает",
        data={
            "name": settings.app_name,
            "version": settings.app_version,
            "description": "Система управления безопасным выходом учеников",
        },
    )


app.include_router(health_router)
app.include_router(api_router)
