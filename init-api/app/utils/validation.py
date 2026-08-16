import re


def is_password_strong(password: str) -> bool:
    return (
        len(password) >= 12
        and re.search(r"[a-zа-я]", password) is not None
        and re.search(r"[A-ZА-Я]", password) is not None
        and re.search(r"\d", password) is not None
        and re.search(r"[^\w\s]", password) is not None
    )


def validate_password_strength(password: str) -> str:
    if not is_password_strong(password):
        raise ValueError(
            "Пароль должен содержать не менее 12 символов, строчную и заглавную "
            "буквы, цифру и специальный символ"
        )
    return password


def is_password_length_valid(password: str) -> bool:
    """Backward-compatible alias for older service code."""
    return is_password_strong(password)
