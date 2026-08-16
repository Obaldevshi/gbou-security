from fastapi import APIRouter
from . import auth, categories, guard, school_admin, system, teacher, user

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(categories.router, prefix="/categories", tags=["categories"])
api_router.include_router(user.router, prefix="/users", tags=["users"])
api_router.include_router(teacher.router, prefix="/teacher", tags=["teacher requests"])
api_router.include_router(guard.router, prefix="/guard", tags=["guard requests"])
api_router.include_router(
    system.router,
    prefix="/system",
    tags=["system administration"],
)
api_router.include_router(
    school_admin.router,
    prefix="/school",
    tags=["school administration"],
)
