import re


def is_password_strong(password: str) -> bool:
    return len(password) >= 8 and re.search(r"[A-Za-zА-Яа-яЁё]", password) is not None


def validate_password_strength(password: str) -> str:
    if not is_password_strong(password):
        raise ValueError("Пароль должен содержать не менее 8 символов и хотя бы одну букву")
    return password


def is_password_length_valid(password: str) -> bool:
    """Backward-compatible alias for older service code."""
    return is_password_strong(password)
