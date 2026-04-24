"""Profiler job processor.

Calls the passive-recon dispatcher with a fixed safe tool set and
writes a stub result to public.jobs. The real enrichment logic is
proprietary and does not ship here.
"""

from __future__ import annotations

import json
from typing import Any

from . import recon_dispatcher as recon

# Fixed safe tool set. Enrichment tools beyond passive DNS live in
# the private repo; keeping the public set narrow makes the scope
# obvious.
DEFAULT_TOOLS = ("dns_lookup", "mx_records", "whois")


async def process_job(
    message: dict[str, Any],
    *,
    pool: Any,
    logger: Any,
    dispatch_fn: Any = None,
) -> dict[str, Any]:
    job = json.loads(message["Body"])
    job_id = job["job_id"]
    subject = (job.get("payload") or {}).get("subject", {})

    logger.info(
        "profiler.job.received",
        job_id=job_id,
        subject_type=job.get("subject_type"),
    )

    dispatch = dispatch_fn or recon.dispatch

    status = "completed"
    error_message: str | None = None
    result: dict[str, Any] = {}

    try:
        result = dispatch(subject, list(DEFAULT_TOOLS))
    except ValueError as err:
        status = "failed"
        error_message = str(err)
        logger.warning(
            "profiler.recon.rejected", job_id=job_id, err=error_message
        )
    except Exception as err:  # noqa: BLE001 — any failure is recorded
        status = "failed"
        error_message = str(err)
        logger.error(
            "profiler.recon.failed", job_id=job_id, err=error_message
        )

    logger.info("profiler.job.completed", job_id=job_id, status=status)

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO public.jobs (
                  job_id, tenant_id, agent, subject_type, status,
                  result, error_message, policy_version,
                  enqueued_at, started_at, completed_at
                )
                VALUES ($1, $2, 'profiler', $3, $4, $5, $6, $7, $8, now(), now())
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
                    json.dumps(result),
                    error_message,
                    job["policy_version"],
                    job["enqueued_at"],
                ],
            )

    return {"status": status, "job_id": job_id}
