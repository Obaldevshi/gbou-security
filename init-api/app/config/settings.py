from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    # legacy keeps existing installations running until a school is migrated.
    deployment_mode: str = "legacy"
    migration_freeze_writes: bool = False

    secret_key: str
    algorithm: str
    access_token_expire_minutes: int = 30
    trusted_device_expire_days: int = 30

    app_name: str = "ГБОУ Безопасность API"
    app_version: str = "1.0.0"
    debug: bool = False

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    cors_origin_regex: str = r"^https://[a-z0-9-]+\.twc1\.net$"

    model_config = SettingsConfigDict(env_file=".env")

    @model_validator(mode="after")
    def validate_production_secret(self) -> "Settings":
        if self.deployment_mode not in {"legacy", "cloud", "local"}:
            raise ValueError("DEPLOYMENT_MODE должен быть legacy, cloud или local")
        if self.deployment_mode == "local" and not self.database_url.startswith("sqlite:///"):
            raise ValueError("Локальный узел должен использовать SQLite на SD-карте")
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
