"""Passive DNS-only recon dispatcher.

Exposes dispatch(subject, tools) where `tools` is a list of generic
method names: 'dns_lookup', 'whois', 'mx_records'. Only passive,
DNS-level operations are implemented. Active scanning, credential
enumeration, and any kind of authenticated probing are explicitly
out of scope — the dispatcher validates the requested tool list
against a hard-coded safe allowlist and raises on anything else.
"""

from __future__ import annotations

import shutil
import subprocess  # noqa: S404 — needed for whois; subprocess call is tightly guarded
from typing import Any

import dns.resolver
import dns.reversename

SAFE_TOOLS = frozenset({"dns_lookup", "whois", "mx_records"})


def _dns_a_records(domain: str) -> list[str]:
    try:
        answers = dns.resolver.resolve(domain, "A", lifetime=5.0)
    except Exception:  # noqa: BLE001 — any DNS failure is recorded as empty
        return []
    return [r.to_text() for r in answers]


def _mx_records(domain: str) -> list[dict[str, Any]]:
    try:
        answers = dns.resolver.resolve(domain, "MX", lifetime=5.0)
    except Exception:  # noqa: BLE001
        return []
    return [
        {"preference": int(r.preference), "exchange": str(r.exchange).rstrip(".")}
        for r in answers
    ]


def _whois(domain: str) -> str:
    """Shell out to whois(1) if present. Returns empty on unavailable.

    The binary is part of the Sprint 2 profiler container image. A
    5-second wall-clock cap keeps a slow registrar from blocking the
    worker.
    """

    exe = shutil.which("whois")
    if exe is None:
        return ""
    try:
        result = subprocess.run(  # noqa: S603 — exe is a full path from shutil.which
            [exe, domain],
            check=False,
            capture_output=True,
            text=True,
            timeout=5.0,
        )
    except subprocess.TimeoutExpired:
        return ""
    return result.stdout or ""


def dispatch(subject: dict[str, Any], tools: list[str]) -> dict[str, Any]:
    """Run the requested tools against the subject and return a
    normalised result dict. Unknown tool names raise ValueError.

    `subject` must carry a `domain` string; anything else is ignored
    by the dispatcher.
    """

    unknown = [t for t in tools if t not in SAFE_TOOLS]
    if unknown:
        raise ValueError(
            f"Unsafe / unknown recon tools requested: {unknown}. "
            f"Allowed passive tools: {sorted(SAFE_TOOLS)}"
        )

    domain = subject.get("domain")
    if not domain or not isinstance(domain, str):
        raise ValueError("subject.domain is required and must be a string")

    result: dict[str, Any] = {"domain": domain}
    if "dns_lookup" in tools:
        result["a_records"] = _dns_a_records(domain)
    if "mx_records" in tools:
        result["mx_records"] = _mx_records(domain)
    if "whois" in tools:
        result["whois_raw"] = _whois(domain)
    return result
