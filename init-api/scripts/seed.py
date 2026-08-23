"""Seed the local GBOU Security school and MVP accounts."""

import hashlib
import os
import re

from app.config.database import SessionLocal
from app.core.security import get_password_hash
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.user import User, UserRole
from app.models.exit_request import SchoolClass, Student, TeacherClassAssignment


DEMO_PASSWORD = "DemoPass123!"
SUPER_ADMIN_LOGIN = "superadmin"


def reset_super_admin_password(db, super_admin: User) -> None:
    password = os.getenv("SUPERADMIN_RESET_PASSWORD", "")
    request_id = os.getenv("SUPERADMIN_RESET_ID", "")
    if not password and not request_id:
        return
    if not password or not request_id:
        raise RuntimeError(
            "SUPERADMIN_RESET_PASSWORD and SUPERADMIN_RESET_ID must be set together"
        )
    if len(password) < 8 or re.search(r"[A-Za-zА-Яа-яЁё]", password) is None:
        raise RuntimeError(
            "SUPERADMIN_RESET_PASSWORD must contain at least 8 characters and one letter"
        )

    marker = hashlib.sha256(request_id.encode("utf-8")).hexdigest()
    if super_admin.password_reset_marker == marker:
        return

    super_admin.hashed_password = get_password_hash(password)
    super_admin.must_change_password = True
    super_admin.is_active = True
    super_admin.password_reset_marker = marker
    db.commit()
    print("Super administrator password reset request applied")


def seed() -> None:
    db = SessionLocal()
    try:
        super_admin = db.query(User).filter(User.login == SUPER_ADMIN_LOGIN).first()
        if super_admin is None:
            super_admin = User(
                school_id=None,
                login=SUPER_ADMIN_LOGIN,
                full_name="Главный администратор",
                phone=None,
                hashed_password=get_password_hash(DEMO_PASSWORD),
                role=UserRole.SUPER_ADMIN,
                is_active=True,
                must_change_password=True,
            )
            db.add(super_admin)
            db.commit()

        reset_super_admin_password(db, super_admin)

        school = db.query(School).filter(School.short_name == "ГБОУ Демо").first()
        if school is None:
            school = School(
                full_name="Государственное бюджетное общеобразовательное учреждение Демо",
                short_name="ГБОУ Демо",
                address="Локальная тестовая школа",
                is_active=True,
            )
            db.add(school)
            db.commit()
            db.refresh(school)

        building = db.query(SchoolBuilding).filter(
            SchoolBuilding.school_id == school.id,
            SchoolBuilding.name == "Основной корпус",
        ).first()
        if building is None:
            building = SchoolBuilding(
                school_id=school.id,
                name="Основной корпус",
                address=school.address,
                is_active=True,
            )
            db.add(building)
            db.commit()
            db.refresh(building)

        accounts = (
            ("school.admin", "Администратор школы", UserRole.SCHOOL_ADMIN),
            ("teacher.demo", "Демо Учитель", UserRole.TEACHER),
            ("guard.demo", "Пост охраны", UserRole.GUARD),
        )
        for login, full_name, role in accounts:
            user = db.query(User).filter(User.login == login).first()
            if user is None:
                user = User(
                    school_id=school.id,
                    building_id=building.id if role in (UserRole.TEACHER, UserRole.GUARD) else None,
                    login=login,
                    full_name=full_name,
                    phone=None,
                    hashed_password=get_password_hash(DEMO_PASSWORD),
                    role=role,
                    is_active=True,
                    must_change_password=True,
                )
                db.add(user)

        db.commit()

        teacher = db.query(User).filter(User.login == "teacher.demo").one()
        school_class = (
            db.query(SchoolClass)
            .filter(
                SchoolClass.school_id == school.id,
                SchoolClass.building_id == building.id,
                SchoolClass.name == "5А",
            )
            .first()
        )
        if school_class is None:
            school_class = SchoolClass(
                school_id=school.id,
                building_id=building.id,
                name="5А",
                is_active=True,
            )
            db.add(school_class)
            db.flush()

        student = (
            db.query(Student)
            .filter(
                Student.school_id == school.id,
                Student.class_id == school_class.id,
                Student.last_name == "Иванов",
                Student.first_name == "Иван",
                Student.middle_name == "Иванович",
            )
            .first()
        )
        if student is None:
            db.add(
                Student(
                    school_id=school.id,
                    class_id=school_class.id,
                    last_name="Иванов",
                    first_name="Иван",
                    middle_name="Иванович",
                    is_active=True,
                )
            )

        assignment = (
            db.query(TeacherClassAssignment)
            .filter(
                TeacherClassAssignment.teacher_id == teacher.id,
                TeacherClassAssignment.class_id == school_class.id,
            )
            .first()
        )
        if assignment is None:
            db.add(
                TeacherClassAssignment(
                    teacher_id=teacher.id,
                    class_id=school_class.id,
                )
            )

        db.commit()
        print("Local MVP accounts are ready:")
        print(f"  {SUPER_ADMIN_LOGIN} / {DEMO_PASSWORD}")
        print(f"  school.admin / {DEMO_PASSWORD}")
        print(f"  teacher.demo / {DEMO_PASSWORD}")
        print(f"  guard.demo / {DEMO_PASSWORD}")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
