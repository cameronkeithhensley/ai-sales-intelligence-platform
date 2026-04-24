"""Long-polling SQS consumer with visibility-timeout heartbeat.

Mirrors the Node sqs.runConsumer behaviour: long-poll for up to 20s,
dispatch handlers with bounded concurrency, heartbeat in-flight
messages via ChangeMessageVisibility, delete on success, release on
failure so the redrive policy bounds re-delivery.
"""

from __future__ import annotations

import asyncio
import threading
from collections.abc import Callable, Awaitable
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def run_consumer(
    *,
    queue_url: str,
    handler: Callable[[dict[str, Any]], Awaitable[None]],
    sqs_client: Any | None = None,
    concurrency: int = 4,
    visibility_heartbeat_seconds: int = 30,
    visibility_extension_seconds: int = 60,
    logger: Any = None,
    should_stop: Callable[[], bool] | None = None,
) -> asyncio.Task:
    """Start the consumer as an asyncio Task. Returns the Task so the
    caller can await it during graceful shutdown.
    """

    client = sqs_client or boto3.client("sqs")
    stop_flag = should_stop or (lambda: False)

    async def heartbeat_loop(receipt_handle: str, done: threading.Event) -> None:
        while not done.is_set():
            await asyncio.sleep(visibility_heartbeat_seconds)
            if done.is_set():
                break
            try:
                client.change_message_visibility(
                    QueueUrl=queue_url,
                    ReceiptHandle=receipt_handle,
                    VisibilityTimeout=visibility_extension_seconds,
                )
            except (BotoCoreError, ClientError) as err:
                if logger:
                    logger.warning("sqs.heartbeat.failed", err=str(err))

    async def process_one(message: dict[str, Any]) -> None:
        receipt = message["ReceiptHandle"]
        done = threading.Event()
        heartbeat_task = asyncio.create_task(heartbeat_loop(receipt, done))
        try:
            await handler(message)
            client.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt)
            if logger:
                logger.debug(
                    "sqs.message.completed",
                    message_id=message.get("MessageId"),
                )
        except Exception as err:  # noqa: BLE001 — handler must not take down the loop
            if logger:
                logger.error(
                    "sqs.handler.failed",
                    message_id=message.get("MessageId"),
                    err=str(err),
                )
            # No delete: visibility expires, redrive policy bounds retries.
        finally:
            done.set()
            heartbeat_task.cancel()
            try:
                await heartbeat_task
            except (asyncio.CancelledError, Exception):
                pass

    async def loop() -> None:
        inflight: set[asyncio.Task] = set()
        while not stop_flag():
            slots = concurrency - len(inflight)
            if slots <= 0:
                _, inflight = await asyncio.wait(
                    inflight, return_when=asyncio.FIRST_COMPLETED
                )
                continue

            try:
                resp = await asyncio.to_thread(
                    client.receive_message,
                    QueueUrl=queue_url,
                    MaxNumberOfMessages=min(slots, 10),
                    WaitTimeSeconds=20,
                    VisibilityTimeout=visibility_extension_seconds,
                )
            except (BotoCoreError, ClientError) as err:
                if logger:
                    logger.error("sqs.poll.failed", err=str(err))
                await asyncio.sleep(1.0)
                continue

            for message in resp.get("Messages", []):
                task = asyncio.create_task(process_one(message))
                inflight.add(task)
                task.add_done_callback(inflight.discard)

        # Drain in-flight on stop.
        if inflight:
            await asyncio.gather(*inflight, return_exceptions=True)

    return asyncio.create_task(loop())
