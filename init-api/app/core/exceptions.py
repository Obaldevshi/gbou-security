from fastapi import HTTPException, status


class BaseError(HTTPException):
    def __init__(self, message: str, status_code: int = 400, code: str = "request_error"):
        self.message = message
        self.code = code
        super().__init__(status_code=status_code, detail=message)


class NotFoundError(BaseError):
    def __init__(self, message: str = "Данные не найдены", code: str = "not_found"):
        super().__init__(message, status.HTTP_404_NOT_FOUND, code)


class ConflictError(BaseError):
    def __init__(self, message: str = "Такая запись уже существует", code: str = "conflict"):
        super().__init__(message, status.HTTP_409_CONFLICT, code)


class ValidationError(BaseError):
    def __init__(self, message: str = "Проверьте введённые данные", code: str = "validation_error"):
        super().__init__(message, status.HTTP_400_BAD_REQUEST, code)


class UnprocessableEntityError(BaseError):
    def __init__(self, message: str = "Проверьте введённые данные", code: str = "validation_error"):
        super().__init__(message, status.HTTP_422_UNPROCESSABLE_CONTENT, code)


class UnauthorizedError(BaseError):
    def __init__(self, message: str = "Необходим вход в систему", code: str = "session_expired"):
        super().__init__(message, status.HTTP_401_UNAUTHORIZED, code)


class ForbiddenError(BaseError):
    def __init__(self, message: str = "Недостаточно прав", code: str = "access_forbidden"):
        super().__init__(message, status.HTTP_403_FORBIDDEN, code)
