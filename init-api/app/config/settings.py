from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
import re


class Settings(BaseSettings):
    database_url: str
    # legacy keeps existing installations running until a school is migrated.
    deployment_mode: str = "legacy"
    migration_freeze_writes: bool = False
    school_devices_enabled: bool = False
    # Enable only after the campus-scoped clients/installers pass cutover checks.
    building_nodes_enabled: bool = False
    gbou_building_id: int | None = Field(default=None, gt=0)
    device_pairing_enabled: bool = False
    login_directory_enabled: bool = False
    login_directory_pepper: str = Field(default='', repr=False)
    school_domain: str = 'gbousecurity.ru'
    # SHA-256 of a separate read-only gateway credential; plaintext never in DB.
    gateway_manifest_token_hash: str = ''
    gateway_public_key: str = ''
    gateway_endpoint: str = ''

    secret_key: str
    algorithm: str
    access_token_expire_minutes: int = 30
    trusted_device_expire_days: int = 30

    app_name: str = "ГБОУ Безопасность API"
    app_version: str = "1.0.0"
    debug: bool = False

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    cors_origin_regex: str = r"^https://[a-z0-9-]+\.twc1\.net$"

    model_config = SettingsConfigDict(env_file=".env", hide_input_in_errors=True)

    @model_validator(mode="after")
    def validate_production_secret(self) -> "Settings":
        if self.building_nodes_enabled and not self.school_devices_enabled:
            raise ValueError('BUILDING_NODES_ENABLED требует SCHOOL_DEVICES_ENABLED')
        if self.deployment_mode not in {"legacy", "cloud", "local"}:
            raise ValueError("DEPLOYMENT_MODE должен быть legacy, cloud или local")
        if self.deployment_mode == "local" and not self.database_url.startswith("sqlite:///"):
            raise ValueError("Локальный узел должен использовать SQLite на SD-карте")
        if self.deployment_mode == 'cloud' and self.login_directory_enabled and (
            len(self.login_directory_pepper.encode()) < 32 or self.login_directory_pepper == self.secret_key
        ):
            raise ValueError('Для справочника нужен отдельный LOGIN_DIRECTORY_PEPPER не менее 32 байт')
        unsafe_values = {"secret", "changeme", "change-me", "your-secret-key"}
        if not self.debug and (
            len(self.secret_key) < 32 or self.secret_key.strip().lower() in unsafe_values
        ):
            raise ValueError("SECRET_KEY в production должен содержать не менее 32 символов")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        origins = [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]
        if self.deployment_mode == 'local' and self.login_directory_enabled:
            origins.append('https://gbousecurity.ru')
        return list(dict.fromkeys(origins))

    @property
    def effective_cors_origin_regex(self) -> str:
        # Registry operations and deletion reauthentication are central, while the
        # administrator may be using the HTTPS site on their school's node.
        # Only cloud mode opts in; local installations retain their exact policy.
        if self.deployment_mode != 'cloud' or not self.school_devices_enabled:
            return self.cors_origin_regex
        domain = self.school_domain.strip().lower()
        label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
        if len(domain) > 253 or not re.fullmatch(label + r'(?:\.' + label + r')+', domain):
            return self.cors_origin_regex  # malformed configuration fails closed
        school_origin = r'^https://' + label + r'\.' + re.escape(domain) + r'$'
        return '(?:' + self.cors_origin_regex + ')|(?:' + school_origin + ')'


settings = Settings()
