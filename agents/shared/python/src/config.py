"""Environment-variable loading with validation.

Every worker declares the subset of environment it needs via a
pydantic-settings BaseConfig subclass. Missing / malformed values raise
at process start, so the task definition is where typos get caught
rather than at the first request.
"""

from __future__ import annotations

from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class BaseConfig(BaseSettings):
    """Base fields every service in the platform reads.

    Service-specific fields are added by subclassing and extending.
    """

    model_config = SettingsConfigDict(
        extra="ignore",
        env_file=None,
        case_sensitive=True,
    )

    APP_ENV: Literal["development", "test", "production"] = "production"
    LOG_LEVEL: Literal["debug", "info", "warning", "error"] = "info"
    AWS_REGION: str = Field(..., min_length=1)
    DATABASE_URL: str = Field(..., min_length=1)
    COGNITO_USER_POOL_ID: str | None = None
    COGNITO_USER_POOL_CLIENT_ID: str | None = None


def load_config(cls: type[BaseConfig], env: dict[str, str] | None = None) -> BaseConfig:
    """Load + validate configuration.

    When `env` is provided (tests), it replaces os.environ for this call.
    """

    if env is None:
        return cls()
    return cls(**{k: v for k, v in env.items() if k in cls.model_fields})
