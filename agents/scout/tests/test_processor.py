"""Scout processor tests.

Use a fake pool + a fake fetch function so the test runs without a
real Postgres or HTTP endpoint.
"""

from __future__ import annotations

import json
import sys
import pathlib
from dataclasses import dataclass
from typing import Any

import pytest

# Allow the test to import the scout package locally.
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src import processor  # noqa: E402


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

    def error(self, event, **kw):
        self.events.append(("error", event, kw))


def _message(url: str | None = "https://example.com/about") -> dict[str, Any]:
    envelope = {
        "job_id": "11111111-1111-1111-1111-111111111111",
        "tenant_id": "22222222-2222-2222-2222-222222222222",
        "agent": "scout",
        "subject_type": "company",
        "enqueued_at": "2026-04-24T00:00:00Z",
        "policy_version": "0.0.0",
        "payload": {"url": url} if url else {},
    }
    return {"MessageId": "aws-msg-1", "Body": json.dumps(envelope)}


@pytest.mark.asyncio
async def test_success_writes_completed_row():
    pool = _FakePool()
    logger = _FakeLogger()

    def fake_fetch(url):
        return type("R", (), {"text": "x" * 123})()

    result = await processor.process_job(
        _message(), pool=pool, logger=logger, fetch_fn=fake_fetch
    )

    assert result == {"status": "completed", "job_id": "11111111-1111-1111-1111-111111111111"}
    assert len(pool.executed) == 1
    sql, params = pool.executed[0]
    assert "INSERT INTO public.jobs" in sql
    assert params[3] == "completed"
    # result payload recorded length of fetched content
    assert json.loads(params[4])["content_length"] == 123


@pytest.mark.asyncio
async def test_fetch_error_records_failed_row():
    pool = _FakePool()
    logger = _FakeLogger()

    def fake_fetch(_url):
        raise RuntimeError("network down")

    result = await processor.process_job(
        _message(), pool=pool, logger=logger, fetch_fn=fake_fetch
    )

    assert result["status"] == "failed"
    sql, params = pool.executed[0]
    assert params[3] == "failed"
    assert params[5] == "network down"
    assert any(e[0] == "error" for e in logger.events)


@pytest.mark.asyncio
async def test_missing_url_does_not_crash():
    pool = _FakePool()
    logger = _FakeLogger()

    result = await processor.process_job(
        _message(url=None), pool=pool, logger=logger, fetch_fn=lambda u: None
    )
    assert result["status"] == "completed"
    sql, params = pool.executed[0]
    # No content fetched, content_length = 0.
    assert json.loads(params[4])["content_length"] == 0
