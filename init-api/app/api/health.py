from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from fastapi import APIRouter, HTTPException

from app.core.dependencies import DatabaseDep

router = APIRouter(tags=["health"])


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/ready")
async def ready(db: DatabaseDep):
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(
            status_code=503,
            detail="База данных временно недоступна",
            headers={"Retry-After": "15"},
        ) from None
    return {"status": "ready"}
