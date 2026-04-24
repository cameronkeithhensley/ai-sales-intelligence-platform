import pytest
from pydantic import ValidationError

import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from config import BaseConfig, load_config  # noqa: E402


class _Minimal(BaseConfig):
    pass


def test_minimal_valid_env_parses():
    cfg = load_config(
        _Minimal,
        env={
            "AWS_REGION": "us-east-1",
            "DATABASE_URL": "postgres://user:pw@host:5432/db",
        },
    )
    assert cfg.AWS_REGION == "us-east-1"
    assert cfg.APP_ENV == "production"
    assert cfg.LOG_LEVEL == "info"


def test_missing_required_fields_raises():
    with pytest.raises(ValidationError):
        load_config(_Minimal, env={})


def test_invalid_log_level_raises():
    with pytest.raises(ValidationError):
        load_config(
            _Minimal,
            env={
                "AWS_REGION": "us-east-1",
                "DATABASE_URL": "postgres://x",
                "LOG_LEVEL": "verbose",
            },
        )


class _WithQueue(BaseConfig):
    QUEUE_URL: str


def test_subclass_adds_fields():
    cfg = load_config(
        _WithQueue,
        env={
            "AWS_REGION": "us-east-1",
            "DATABASE_URL": "postgres://x",
            "QUEUE_URL": "https://sqs.us-east-1.amazonaws.com/000000000000/dev-scout",
        },
    )
    assert cfg.QUEUE_URL.startswith("https://")
