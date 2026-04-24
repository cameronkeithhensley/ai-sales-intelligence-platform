"""Scout SQS consumer.

Wraps the shared run_consumer with scout's processor.
"""

from __future__ import annotations

import sys
import pathlib
from typing import Any

# The shared layer lives one level up; for a runtime deploy either
# install agents/shared/python as a package into the image or add its
# src to sys.path here. The public stub uses sys.path so the service
# still runs locally from a fresh checkout.
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
    concurrency: int = 4,
) -> Any:
    async def handler(message: dict[str, Any]) -> None:
        await processor.process_job(message, pool=pool, logger=logger)

    return run_consumer(
        queue_url=queue_url,
        handler=handler,
        concurrency=concurrency,
        logger=logger,
    )
