"""Harvester job processor.

Reads a single SQS message, resolves an adapter from the adapters
registry, calls fetch(), and writes the outcome to public.jobs. In
the public repo the registry is empty by design, so the resolve()
call raises KeyError on every real job and the processor records
'failed' — which is the expected portfolio behaviour.

Tests cover the success path by registering a mock adapter.
"""

from __future__ import annotations

import json
from typing import Any

from . import adapters as adapters_mod


async def process_job(
    message: dict[str, Any],
    *,
    pool: Any,
    logger: Any,
) -> dict[str, Any]:
    job = json.loads(message["Body"])
    job_id = job["job_id"]
    adapter_name = (job.get("payload") or {}).get("adapter")

    logger.info(
        "harvester.job.received",
        job_id=job_id,
        adapter=adapter_name,
        subject_type=job.get("subject_type"),
    )

    status = "completed"
    error_message: str | None = None
    result_payload: dict[str, Any] = {}

    try:
        if not adapter_name:
            raise KeyError("payload.adapter is required")
        adapter = adapters_mod.resolve(adapter_name)
        subject = job.get("payload", {}).get("subject", {})
        result_payload = adapter.fetch(subject) or {}
    except KeyError as err:
        status = "failed"
        error_message = str(err)
        logger.warning(
            "harvester.adapter.missing",
            job_id=job_id,
            adapter=adapter_name,
            err=error_message,
        )
    except Exception as err:  # noqa: BLE001 — adapter failures are recorded in DB
        status = "failed"
        error_message = str(err)
        logger.error(
            "harvester.adapter.failed",
            job_id=job_id,
            adapter=adapter_name,
            err=error_message,
        )

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO public.jobs (
                  job_id, tenant_id, agent, subject_type, status,
                  result, error_message, policy_version,
                  enqueued_at, started_at, completed_at
                )
                VALUES ($1, $2, 'harvester', $3, $4, $5, $6, $7, $8, now(), now())
                ON CONFLICT (job_id) DO UPDATE
                  SET status        = EXCLUDED.status,
                      result        = EXCLUDED.result,
                      error_message = EXCLUDED.error_message,
                      completed_at  = EXCLUDED.completed_at
                """,
                [
                    job_id,
                    job["tenant_id"],
                    job["subject_type"],
                    status,
                    json.dumps(result_payload),
                    error_message,
                    job["policy_version"],
                    job["enqueued_at"],
                ],
            )

    return {"status": status, "job_id": job_id}
