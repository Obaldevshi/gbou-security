from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str

    secret_key: str
    algorithm: str
    access_token_expire_minutes: int = 30

    app_name: str = "ГБОУ Безопасность API"
    app_version: str = "1.0.0"
    debug: bool = False

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    cors_origin_regex: str = r"^https://[a-z0-9-]+\.twc1\.net$"
    login_rate_limit: int = 10
    login_rate_window_seconds: int = 300

    model_config = SettingsConfigDict(env_file=".env")

    @model_validator(mode="after")
    def validate_production_secret(self) -> "Settings":
        unsafe_values = {"secret", "changeme", "change-me", "your-secret-key"}
        if not self.debug and (
            len(self.secret_key) < 32 or self.secret_key.strip().lower() in unsafe_values
        ):
            raise ValueError("SECRET_KEY в production должен содержать не менее 32 символов")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()
