"""Scout worker entry point.

Boots the asyncio event loop, builds the DB pool + logger, and hands
control to the SQS consumer. Workers don't register with the ALB but
we open a tiny /healthz server on HEALTH_PORT so operators can curl
the task while debugging.
"""

from __future__ import annotations

import asyncio
import http.server
import os
import sys
import pathlib
import signal
import threading

sys.path.insert(
    0,
    str(pathlib.Path(__file__).resolve().parents[2] / "shared" / "python" / "src"),
)
from config import BaseConfig, load_config  # noqa: E402
from db import make_pool  # noqa: E402
from logger import build_logger  # noqa: E402

from .consumer import start_consumer


class Config(BaseConfig):
    QUEUE_URL: str
    CONCURRENCY: int = 4
    HEALTH_PORT: int = 8080


class _HealthzHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_args, **_kwargs):
        # Silence the default stderr access log; structured logger
        # handles observability.
        pass


def _run_healthz(port: int) -> http.server.HTTPServer:
    server = http.server.HTTPServer(("0.0.0.0", port), _HealthzHandler)  # noqa: S104
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


async def _async_main() -> None:
    cfg = load_config(Config, env=dict(os.environ))
    logger = build_logger(level=cfg.LOG_LEVEL, service="scout")
    pool = make_pool(cfg.DATABASE_URL)

    healthz = _run_healthz(cfg.HEALTH_PORT)

    stop_flag = {"value": False}

    def _request_stop(_sig, _frame):
        stop_flag["value"] = True

    signal.signal(signal.SIGTERM, _request_stop)
    signal.signal(signal.SIGINT, _request_stop)

    consumer_task = start_consumer(
        queue_url=cfg.QUEUE_URL,
        pool=pool,
        logger=logger,
        concurrency=cfg.CONCURRENCY,
    )

    logger.info(
        "scout.started",
        queue_url=cfg.QUEUE_URL,
        concurrency=cfg.CONCURRENCY,
        sprint=3,
    )

    try:
        # Poll the stop flag so a SIGTERM cleans up the consumer.
        while not stop_flag["value"]:
            await asyncio.sleep(1.0)
    finally:
        logger.info("scout.shutdown")
        consumer_task.cancel()
        healthz.shutdown()
        pool.close()


def main() -> None:
    try:
        asyncio.run(_async_main())
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
