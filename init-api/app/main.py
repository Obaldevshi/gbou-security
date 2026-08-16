import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError

from app.config.settings import settings
from app.api.v1.router import api_router
from app.api.health import router as health_router
from app.core.exceptions import BaseError
from app.core.responses import SuccessResponse
from app.core.middleware import LoginRateLimitMiddleware, RequestLoggingMiddleware
from app.constants.messages import ValidationMessages

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

app = FastAPI(title=settings.app_name, version=settings.app_version, debug=settings.debug)

app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(LoginRateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(BaseError)
async def base_error_handler(_: Request, exc: BaseError):
    return JSONResponse(
        status_code=exc.status_code,
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
