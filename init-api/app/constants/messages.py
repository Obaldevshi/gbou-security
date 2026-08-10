from enum import Enum


class ValidationMessages(Enum):
    PASSWORD_TOO_SHORT = "Пароль должен содержать не менее 8 символов"
    REQUIRED_FIELDS = "Заполните обязательные поля"


class AuthMessages(Enum):
    LOGIN_SUCCESS = "Вход выполнен"
    INVALID_CREDENTIALS = "Неверный логин или пароль"
    USER_NOT_FOUND = "Пользователь не найден"
    ACCOUNT_INACTIVE = "Учётная запись отключена"
    SCHOOL_INACTIVE = "Школа временно отключена"
    SCHOOL_REQUIRED = "Пользователь не привязан к школе"
    SESSION_EXPIRED = "Сессия истекла. Войдите снова"
    ACCESS_FORBIDDEN = "Нет прав на это действие"


class UserMessages(Enum):
    RETRIEVED_SUCCESS = "Пользователь получен"
    UPDATED_SUCCESS = "Profile updated successfully"
    PASSWORD_CHANGED_SUCCESS = "Password changed successfully"
    INVALID_CURRENT_PASSWORD = "Invalid current password"


class CategoryMessages(Enum):
    CREATED_SUCCESS = "Category created successfully"
    UPDATED_SUCCESS = "Category updated successfully"
    DELETED_SUCCESS = "Category deleted successfully"
    RETRIEVED_SUCCESS = "Categories retrieved successfully"
    NOT_FOUND = "Category not found"
    ALREADY_EXISTS = "Category already exists"


class ExitRequestMessages(Enum):
    CLASSES_RETRIEVED = "Доступные классы получены"
    STUDENTS_RETRIEVED = "Ученики класса получены"
    CREATED = "Заявка отправлена"
    CLASS_NOT_AVAILABLE = "Класс недоступен"
    STUDENT_NOT_AVAILABLE = "Ученик недоступен"
    CUSTOM_REASON_REQUIRED = "Укажите свою причину"
    CUSTOM_REASON_NOT_ALLOWED = (
        "Своя причина допустима только для варианта «Своя причина»"
    )
    TIMEZONE_REQUIRED = "Укажите время выхода с часовым поясом"
    SCHEDULED_AT_IN_PAST = "Укажите будущее время выхода"
    ACTIVE_REQUEST_EXISTS = "Для этого ученика уже есть ожидающая заявка"
    GUARD_QUEUE_RETRIEVED = "Очередь заявок получена"
    RELEASED = "Выход ученика подтверждён"
    REQUEST_NOT_AVAILABLE = "Заявка недоступна"
    REQUEST_ALREADY_PROCESSED = "Заявка уже обработана"
    TEACHER_REQUESTS_RETRIEVED = "Заявки учителя получены"


class ErrorMessages(Enum):
    INTERNAL_SERVER_ERROR = "An internal server error occurred"
    NOT_FOUND = "Resource not found"
    FORBIDDEN = "Access forbidden"
    BAD_REQUEST = "Bad request"
