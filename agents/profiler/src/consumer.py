"""Profiler SQS consumer."""

from __future__ import annotations

import sys
import pathlib
from typing import Any

sys.path.insert(
    0,
    str(pathlib.Path(__file__).resolve().parents[2] / "shared" / "python" / "src"),
)
from sqs_consumer import run_consumer  # noqa: E402

from . import processor  # noqa: E402


def start_consumer(
    *,
    queue_url: str,
    pool: Any,
    logger: Any,
    concurrency: int = 2,
) -> Any:
    async def handler(message: dict[str, Any]) -> None:
        await processor.process_job(message, pool=pool, logger=logger)

    return run_consumer(
        queue_url=queue_url,
        handler=handler,
        concurrency=concurrency,
        logger=logger,
    )
