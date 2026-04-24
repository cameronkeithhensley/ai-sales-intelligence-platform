"""Scout job processor.

Reads a single SQS message, invokes the generic scraper stub against
the subject URL carried in the payload, and writes a completion row
to public.jobs. No result extraction — the production version ships
per-source extractors that are proprietary.
"""

from __future__ import annotations

import json
from typing import Any

from . import scraper_stub


async def process_job(
    message: dict[str, Any],
    *,
    pool: Any,
    logger: Any,
    fetch_fn: Any = None,
) -> dict[str, Any]:
    """Process a single SQS message.

    `pool` is a psycopg ConnectionPool; `logger` a structlog bound
    logger. `fetch_fn` is injectable for tests — defaults to the
    module-level scraper_stub.fetch.
    """

    job = json.loads(message["Body"])
    job_id = job["job_id"]
    url = (job.get("payload") or {}).get("url")

    logger.info("scout.job.received", job_id=job_id, subject_type=job.get("subject_type"))

    fetch = fetch_fn or scraper_stub.fetch

    status = "completed"
    error_message: str | None = None
    content_length = 0
    try:
        result = fetch(url) if url else None
        if result is not None:
            content_length = len(result.text or "")
    except Exception as err:  # noqa: BLE001 — we record any failure in public.jobs
        status = "failed"
        error_message = str(err)
        logger.error("scout.fetch.failed", job_id=job_id, err=error_message)

    logger.info(
        "scout.job.completed",
        job_id=job_id,
        status=status,
        content_length=content_length,
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
                VALUES ($1, $2, 'scout', $3, $4, $5, $6, $7, $8, now(), now())
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
                    json.dumps({"content_length": content_length}),
                    error_message,
                    job["policy_version"],
                    job["enqueued_at"],
                ],
            )

    return {"status": status, "job_id": job_id}
