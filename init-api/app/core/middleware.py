import logging
import time
from collections import defaultdict, deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config.database import SessionLocal
from app.core.security import verify_token
from app.models.audit_log import AuditLog
from app.models.user import User
from app.config.settings import settings

logger = logging.getLogger("app.request")


class AppMetrics:
    started_at = time.time()
    total_requests = 0
    server_errors = 0
    in_flight = 0
    total_duration_ms = 0.0

    @classmethod
    def snapshot(cls) -> dict:
        average = cls.total_duration_ms / cls.total_requests if cls.total_requests else 0
        return {
            "uptime_seconds": int(time.time() - cls.started_at),
            "total_requests": cls.total_requests,
            "server_errors": cls.server_errors,
            "in_flight": cls.in_flight,
            "average_duration_ms": round(average, 2),
        }


class LoginRateLimitMiddleware(BaseHTTPMiddleware):
    attempts: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next):
        if request.method != "POST" or request.url.path != "/api/v1/auth/login":
            return await call_next(request)
        key = request.client.host if request.client else "unknown"
        now = time.monotonic()
        bucket = self.attempts[key]
        cutoff = now - settings.login_rate_window_seconds
        while bucket and bucket[0] < cutoff:
            bucket.popleft()
        if len(bucket) >= settings.login_rate_limit:
            retry_after = max(1, int(settings.login_rate_window_seconds - (now - bucket[0])))
            return JSONResponse(
                status_code=429,
                headers={"Retry-After": str(retry_after)},
                content={
                    "status_code": 429,
                    "code": "login_rate_limited",
                    "message": "Слишком много попыток входа. Повторите позже",
                    "detail": "Слишком много попыток входа. Повторите позже",
                },
            )
        bucket.append(now)
        response = await call_next(request)
        if response.status_code < 400:
            bucket.clear()
        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        AppMetrics.in_flight += 1
        try:
            response = await call_next(request)
        finally:
            AppMetrics.in_flight -= 1
        duration_ms = (time.perf_counter() - start) * 1000
        AppMetrics.total_requests += 1
        AppMetrics.total_duration_ms += duration_ms
        if response.status_code >= 500:
            AppMetrics.server_errors += 1
        logger.info(
            "%s %s %s %.2fms",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        if request.method in {"POST", "PATCH", "PUT", "DELETE"}:
            self._write_audit(request, response.status_code)
        return response

    @staticmethod
    def _write_audit(request: Request, status_code: int) -> None:
        authorization = request.headers.get("authorization", "")
        token = authorization.removeprefix("Bearer ").strip()
        user_id = verify_token(token) if token else None
        if user_id is None:
            return
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if user is None:
                return
            db.add(
                AuditLog(
                    actor_id=user.id,
                    school_id=user.school_id,
                    method=request.method,
                    path=request.url.path,
                    status_code=status_code,
                    ip_address=request.client.host if request.client else None,
                    user_agent=request.headers.get("user-agent", "")[:300] or None,
                )
            )
            db.commit()
        except Exception:
            db.rollback()
            logger.exception("Failed to write audit log")
        finally:
            db.close()
