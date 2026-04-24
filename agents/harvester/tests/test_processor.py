"""Harvester processor tests.

Two paths matter for the public portfolio build:

1. Success: a mock adapter is registered, the processor resolves it,
   calls fetch(), writes a 'completed' row with the adapter's result.
2. Empty-registry: the expected default state. resolve() raises
   KeyError, the processor writes a 'failed' row whose error_message
   makes the situation obvious.
"""

from __future__ import annotations

import json
import sys
import pathlib
from dataclasses import dataclass
from typing import Any

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import processor  # noqa: E402
from src import adapters as adapters_mod  # noqa: E402


@dataclass
class _FakeCursor:
    executed: list

    def execute(self, sql: str, params=None):
        self.executed.append((sql, params))

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False


class _FakeConn:
    def __init__(self, executed):
        self._executed = executed

    def cursor(self):
        return _FakeCursor(self._executed)

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False


class _FakePool:
    def __init__(self):
        self.executed: list = []

    def connection(self):
        return _FakeConn(self.executed)


class _FakeLogger:
    def __init__(self):
        self.events: list = []

    def info(self, event, **kw):
        self.events.append(("info", event, kw))

    def warning(self, event, **kw):
        self.events.append(("warning", event, kw))

    def error(self, event, **kw):
        self.events.append(("error", event, kw))


def _message(adapter: str | None = None) -> dict[str, Any]:
    return {
        "MessageId": "aws-msg-1",
        "Body": json.dumps(
            {
                "job_id": "11111111-1111-1111-1111-111111111111",
                "tenant_id": "22222222-2222-2222-2222-222222222222",
                "agent": "harvester",
                "subject_type": "company",
                "enqueued_at": "2026-04-24T00:00:00Z",
                "policy_version": "0.0.0",
                "payload": {"adapter": adapter, "subject": {"id": "s-1"}}
                if adapter is not None
                else {},
            }
        ),
    }


class _MockAdapter:
    name = "mock"
    tenant_types = frozenset({"standard"})

    def fetch(self, _subject):
        return {"hit": True, "value": 42}


@pytest.mark.asyncio
async def test_registered_adapter_writes_completed():
    adapters_mod.register(_MockAdapter())
    try:
        pool = _FakePool()
        logger = _FakeLogger()
        result = await processor.process_job(
            _message(adapter="mock"), pool=pool, logger=logger
        )
        assert result["status"] == "completed"
        sql, params = pool.executed[0]
        assert params[3] == "completed"
        assert json.loads(params[4]) == {"hit": True, "value": 42}
    finally:
        adapters_mod.unregister("mock")


@pytest.mark.asyncio
async def test_empty_registry_writes_failed_cleanly():
    # Registry is empty by default in the public portfolio build.
    assert "not-a-real-adapter" not in adapters_mod.REGISTRY
    pool = _FakePool()
    logger = _FakeLogger()
    result = await processor.process_job(
        _message(adapter="not-a-real-adapter"), pool=pool, logger=logger
    )
    assert result["status"] == "failed"
    sql, params = pool.executed[0]
    assert params[3] == "failed"
    assert "not-a-real-adapter" in params[5]
    assert any(e[0] == "warning" for e in logger.events)


@pytest.mark.asyncio
async def test_missing_adapter_name_writes_failed():
    pool = _FakePool()
    logger = _FakeLogger()
    result = await processor.process_job(_message(adapter=None), pool=pool, logger=logger)
    assert result["status"] == "failed"


def test_resolve_raises_keyerror_with_helpful_message():
    with pytest.raises(KeyError, match="proprietary"):
        adapters_mod.resolve("nothing")
