"""Sprint 2 stub - real passive-recon worker lands in Sprint 3."""

import json
import sys
import time


def main() -> None:
    print(
        json.dumps({"msg": "service-started", "service": "profiler", "sprint": 2}),
        flush=True,
    )
    # Worker loop placeholder: keep the ECS task alive for health checks.
    while True:
        time.sleep(60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
