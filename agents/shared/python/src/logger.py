"""Structured JSON logger built on structlog.

The REDACT_KEYS list MUST stay in sync with the known-secret env var
names across the platform. Any new secret env var added to any service
goes here too.
"""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog

REDACT_KEYS: frozenset[str] = frozenset(
    {
        "DATABASE_URL",
        "JWT_SIGNING_KEY",
        "ANTHROPIC_API_KEY",
        "SMS_PROVIDER_TOKEN",
        "EMAIL_DELIVERY_PROVIDER_TOKEN",
        "PERSON_DATA_API_KEY",
        "password",
        "secret",
        "authorization",
        "cookie",
    }
)


def _redact(_logger: Any, _name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    """Replace values whose key matches REDACT_KEYS with '[redacted]'."""

    def walk(obj: Any) -> Any:
        if isinstance(obj, dict):
            return {
                k: ("[redacted]" if k in REDACT_KEYS else walk(v))
                for k, v in obj.items()
            }
        if isinstance(obj, list):
            return [walk(item) for item in obj]
        return obj

    return walk(event_dict)  # type: ignore[return-value]


def build_logger(*, level: str = "info", service: str | None = None) -> structlog.BoundLogger:
    """Configure structlog with JSON output, ISO timestamps, and redaction."""

    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, level.upper(), logging.INFO),
    )

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            _redact,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, level.upper(), logging.INFO),
        ),
        cache_logger_on_first_use=True,
    )

    logger = structlog.get_logger()
    if service:
        logger = logger.bind(service=service)
    return logger
