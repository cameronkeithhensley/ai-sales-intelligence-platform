"""Shared Python runtime for ai-sales-intelligence-platform services.

Each agent worker imports the subset it needs — config loading,
DB pool + tenant routing, Cognito JWT verification, SQS consumer,
structured logging. The Node.js layer under agents/shared/node/
implements the same five primitives for the Node services.
"""

from .config import BaseConfig, load_config
from .db import make_pool, with_tenant, validate_ident
from .jwt_verifier import JwtVerifier, Claims
from .logger import build_logger, REDACT_KEYS
from .sqs_consumer import run_consumer

__all__ = [
    "BaseConfig",
    "load_config",
    "make_pool",
    "with_tenant",
    "validate_ident",
    "JwtVerifier",
    "Claims",
    "build_logger",
    "REDACT_KEYS",
    "run_consumer",
]
