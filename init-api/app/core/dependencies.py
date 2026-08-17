from collections.abc import Callable
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config.database import get_db
from app.constants.messages import AuthMessages
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.security import verify_token
from app.models.user import User, UserRole
from app.repositories.category_repository import CategoryRepository
from app.repositories.school_repository import SchoolRepository
from app.repositories.school_building_repository import SchoolBuildingRepository
from app.repositories.school_class_admin_repository import SchoolClassAdminRepository
from app.repositories.user_repository import UserRepository
from app.repositories.student_admin_repository import StudentAdminRepository
from app.repositories.teacher_admin_repository import TeacherAdminRepository
from app.repositories.guard_admin_repository import GuardAdminRepository
from app.repositories.exit_request_repository import ExitRequestRepository
from app.services.auth_service import AuthService
from app.services.category_service import CategoryService
from app.services.school_service import SchoolService
from app.services.school_building_service import SchoolBuildingService
from app.services.school_admin_service import SchoolAdminService
from app.services.school_class_admin_service import SchoolClassAdminService
from app.services.user_service import UserService
from app.services.student_admin_service import StudentAdminService
from app.services.teacher_admin_service import TeacherAdminService
from app.services.guard_admin_service import GuardAdminService
from app.services.exit_request_service import ExitRequestService
from app.repositories.audit_log_repository import AuditLogRepository
from app.services.audit_log_service import AuditLogService
from app.repositories.report_repository import ReportRepository
from app.services.report_service import ReportService


bearer_scheme = HTTPBearer(auto_error=False)
DatabaseDep = Annotated[Session, Depends(get_db)]


def get_user_repository(db: DatabaseDep) -> UserRepository:
    return UserRepository(db)


def get_current_user(
    repository: Annotated[UserRepository, Depends(get_user_repository)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    token = credentials.credentials if credentials else None
    user_id = verify_token(token) if token else None
    if user_id is None:
        raise UnauthorizedError(AuthMessages.SESSION_EXPIRED.value, code="session_expired")

    user = repository.get_by_id(user_id)
    if user is None:
        raise UnauthorizedError(AuthMessages.SESSION_EXPIRED.value, code="session_expired")

    AuthService.ensure_user_can_access(user)
    return user


CurrentUserDep = Annotated[User, Depends(get_current_user)]


def require_roles(*allowed_roles: UserRole) -> Callable[[CurrentUserDep], User]:
    def dependency(current_user: CurrentUserDep) -> User:
        if current_user.must_change_password:
            raise ForbiddenError(
                "Сначала смените временный пароль",
                code="password_change_required",
            )
        if current_user.role not in allowed_roles:
            raise ForbiddenError(
                AuthMessages.ACCESS_FORBIDDEN.value,
                code="access_forbidden",
            )
        return current_user

    return dependency


TeacherUserDep = Annotated[
    User,
    Depends(require_roles(UserRole.TEACHER)),
]
GuardUserDep = Annotated[
    User,
    Depends(require_roles(UserRole.GUARD)),
]


def get_user_service(
    repository: Annotated[UserRepository, Depends(get_user_repository)],
) -> UserService:
    return UserService(repository)


def get_auth_service(
    repository: Annotated[UserRepository, Depends(get_user_repository)],
) -> AuthService:
    return AuthService(repository)


def get_category_service(db: DatabaseDep) -> CategoryService:
    return CategoryService(db)


def get_exit_request_repository(db: DatabaseDep) -> ExitRequestRepository:
    return ExitRequestRepository(db)


def get_exit_request_service(
    repository: Annotated[
        ExitRequestRepository,
        Depends(get_exit_request_repository),
    ],
) -> ExitRequestService:
    return ExitRequestService(repository)


def get_school_repository(db: DatabaseDep) -> SchoolRepository:
    return SchoolRepository(db)


def get_school_service(
    repository: Annotated[SchoolRepository, Depends(get_school_repository)],
) -> SchoolService:
    return SchoolService(repository)


def get_school_admin_service(
    users: Annotated[UserRepository, Depends(get_user_repository)],
    schools: Annotated[SchoolRepository, Depends(get_school_repository)],
) -> SchoolAdminService:
    return SchoolAdminService(users, schools)


def get_school_class_admin_service(db: DatabaseDep) -> SchoolClassAdminService:
    return SchoolClassAdminService(SchoolClassAdminRepository(db))


def get_school_building_service(db: DatabaseDep) -> SchoolBuildingService:
    return SchoolBuildingService(SchoolBuildingRepository(db))


def get_student_admin_service(db: DatabaseDep) -> StudentAdminService:
    return StudentAdminService(StudentAdminRepository(db))


def get_teacher_admin_service(db: DatabaseDep) -> TeacherAdminService:
    return TeacherAdminService(TeacherAdminRepository(db))


def get_guard_admin_service(db: DatabaseDep) -> GuardAdminService:
    return GuardAdminService(GuardAdminRepository(db))


UserServiceDep = Annotated[UserService, Depends(get_user_service)]
AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]
CategoryServiceDep = Annotated[CategoryService, Depends(get_category_service)]
ExitRequestServiceDep = Annotated[
    ExitRequestService,
    Depends(get_exit_request_service),
]
SchoolServiceDep = Annotated[SchoolService, Depends(get_school_service)]
SchoolAdminServiceDep = Annotated[
    SchoolAdminService,
    Depends(get_school_admin_service),
]
SchoolClassAdminServiceDep = Annotated[
    SchoolClassAdminService,
    Depends(get_school_class_admin_service),
]
SchoolBuildingServiceDep = Annotated[
    SchoolBuildingService,
    Depends(get_school_building_service),
]
StudentAdminServiceDep = Annotated[
    StudentAdminService,
    Depends(get_student_admin_service),
]
TeacherAdminServiceDep = Annotated[
    TeacherAdminService,
    Depends(get_teacher_admin_service),
]
GuardAdminServiceDep = Annotated[
    GuardAdminService,
    Depends(get_guard_admin_service),
]


def get_audit_log_service(db: DatabaseDep) -> AuditLogService:
    return AuditLogService(AuditLogRepository(db))


AuditLogServiceDep = Annotated[AuditLogService, Depends(get_audit_log_service)]


def get_report_service(db: DatabaseDep) -> ReportService:
    return ReportService(ReportRepository(db))


ReportServiceDep = Annotated[ReportService, Depends(get_report_service)]
