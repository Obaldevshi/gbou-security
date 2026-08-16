from datetime import datetime

from sqlalchemy.orm import Session, joinedload

from app.models.exit_request import ExitRequest
from app.models.school import School
from app.models.user import User


class ReportRepository:
    def __init__(self, db: Session):
        self.db = db

    def schools(self) -> list[School]:
        return self.db.query(School).order_by(School.short_name.asc()).all()

    def users(self) -> list[User]:
        return self.db.query(User).order_by(User.role.asc(), User.full_name.asc()).all()

    def requests(self, school_id: int, date_from: datetime | None, date_to: datetime | None) -> list[ExitRequest]:
        query = self.db.query(ExitRequest).options(
            joinedload(ExitRequest.school_class),
            joinedload(ExitRequest.student),
            joinedload(ExitRequest.teacher),
        ).filter(ExitRequest.school_id == school_id)
        if date_from is not None:
            query = query.filter(ExitRequest.created_at >= date_from)
        if date_to is not None:
            query = query.filter(ExitRequest.created_at <= date_to)
        return query.order_by(ExitRequest.created_at.desc()).all()
