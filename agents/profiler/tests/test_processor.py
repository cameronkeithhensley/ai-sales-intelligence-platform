"""Profiler processor tests.

Covers the success path with a mocked dispatcher and the
no-subject-resolvable path where the dispatcher raises ValueError.
Also sanity-checks that the dispatcher's safe-allowlist refuses a
non-passive tool name.
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
from src import recon_dispatcher  # noqa: E402


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


def _message(domain: str | None = "example.com") -> dict[str, Any]:
    return {
        "MessageId": "aws-msg-1",
        "Body": json.dumps(
            {
                "job_id": "11111111-1111-1111-1111-111111111111",
                "tenant_id": "22222222-2222-2222-2222-222222222222",
                "agent": "profiler",
                "subject_type": "company",
                "enqueued_at": "2026-04-24T00:00:00Z",
                "policy_version": "0.0.0",
                "payload": {"subject": {"domain": domain} if domain else {}},
            }
        ),
    }


@pytest.mark.asyncio
async def test_success_with_mocked_dispatcher():
    pool = _FakePool()
    logger = _FakeLogger()

    def fake_dispatch(subject, tools):
        return {"domain": subject["domain"], "a_records": ["192.0.2.1"]}

    result = await processor.process_job(
        _message(), pool=pool, logger=logger, dispatch_fn=fake_dispatch
    )
    assert result["status"] == "completed"
    sql, params = pool.executed[0]
    assert params[3] == "completed"
    payload = json.loads(params[4])
    assert payload["a_records"] == ["192.0.2.1"]


@pytest.mark.asyncio
async def test_missing_subject_writes_failed():
    pool = _FakePool()
    logger = _FakeLogger()

    def fake_dispatch(_subject, _tools):
        raise ValueError("subject.domain is required and must be a string")

    result = await processor.process_job(
        _message(domain=None), pool=pool, logger=logger, dispatch_fn=fake_dispatch
    )
    assert result["status"] == "failed"
    sql, params = pool.executed[0]
    assert "subject.domain" in params[5]


def test_dispatch_rejects_unsafe_tool_name():
    with pytest.raises(ValueError, match="Unsafe"):
        recon_dispatcher.dispatch({"domain": "example.com"}, ["nmap_scan"])


def test_dispatch_requires_string_domain():
    with pytest.raises(ValueError, match="subject.domain"):
        recon_dispatcher.dispatch({}, ["dns_lookup"])
    with pytest.raises(ValueError, match="subject.domain"):
        recon_dispatcher.dispatch({"domain": 42}, ["dns_lookup"])
