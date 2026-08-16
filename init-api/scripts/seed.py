"""Seed the local GBOU Security school and MVP accounts."""

from app.config.database import SessionLocal
from app.core.security import get_password_hash
from app.models.school import School
from app.models.user import User, UserRole
from app.models.exit_request import SchoolClass, Student, TeacherClassAssignment


DEMO_PASSWORD = "DemoPass123!"
SUPER_ADMIN_LOGIN = "superadmin"


def seed() -> None:
    db = SessionLocal()
    try:
        super_admin = db.query(User).filter(User.login == SUPER_ADMIN_LOGIN).first()
        if super_admin is None:
            db.add(
                User(
                    school_id=None,
                    login=SUPER_ADMIN_LOGIN,
                    full_name="Главный администратор",
                    phone=None,
                    hashed_password=get_password_hash(DEMO_PASSWORD),
                    role=UserRole.SUPER_ADMIN,
                    is_active=True,
                )
            )
            db.commit()

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

        accounts = (
            ("teacher.demo", "Демо Учитель", UserRole.TEACHER),
            ("guard.demo", "Пост охраны", UserRole.GUARD),
        )
        for login, full_name, role in accounts:
            user = db.query(User).filter(User.login == login).first()
            if user is None:
                user = User(
                    school_id=school.id,
                    login=login,
                    full_name=full_name,
                    phone=None,
                    hashed_password=get_password_hash(DEMO_PASSWORD),
                    role=role,
                    is_active=True,
                )
                db.add(user)

        db.commit()

        teacher = db.query(User).filter(User.login == "teacher.demo").one()
        school_class = (
            db.query(SchoolClass)
            .filter(
                SchoolClass.school_id == school.id,
                SchoolClass.name == "5А",
            )
            .first()
        )
        if school_class is None:
            school_class = SchoolClass(
                school_id=school.id,
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
        print(f"  teacher.demo / {DEMO_PASSWORD}")
        print(f"  guard.demo / {DEMO_PASSWORD}")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
