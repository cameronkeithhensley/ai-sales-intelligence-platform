"""Postgres pool + per-tenant search_path routing.

Mirrors the Node side: workers acquire a pooled connection and run
per-tenant queries inside `with_tenant(pool, schema, ...)` which pins
search_path for the duration of the block and resets on exit.
"""

from __future__ import annotations

import re
from contextlib import contextmanager
from typing import Iterator

import psycopg
from psycopg_pool import ConnectionPool

_IDENT_RE = re.compile(r"^[a-z][a-z0-9_]{0,62}$")


def validate_ident(ident: str) -> str:
    """Validate a Postgres identifier and return it unchanged.

    Tenant schema names originate in the tenants table, but we still
    validate before interpolating: SET search_path does not accept
    bound parameters, so a compromised row or a bad typo cannot be
    allowed to turn into SQL injection.
    """

    if not isinstance(ident, str) or not _IDENT_RE.match(ident):
        raise ValueError(
            f"Invalid SQL identifier: {ident!r}. "
            "Must match /^[a-z][a-z0-9_]{0,62}$/."
        )
    return ident


def make_pool(connection_string: str, *, min_size: int = 1, max_size: int = 10) -> ConnectionPool:
    """Build a psycopg3 ConnectionPool with conservative defaults.

    Fargate task counts are typically low and RDS max_connections is
    not infinite; err small rather than large.
    """

    return ConnectionPool(
        conninfo=connection_string,
        min_size=min_size,
        max_size=max_size,
        open=True,
    )


@contextmanager
def with_tenant(pool: ConnectionPool, tenant_schema: str) -> Iterator[psycopg.Connection]:
    """Acquire a pooled connection whose search_path is pinned to the
    tenant schema for the duration of the context.

    Usage:
        with with_tenant(pool, "tenant_abc") as conn:
            conn.execute("SELECT ... FROM some_tenant_table ...")
    """

    ident = validate_ident(tenant_schema)
    quoted = f'"{ident}"'

    with pool.connection() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(f"SET search_path TO {quoted}, public")
            yield conn
        finally:
            try:
                with conn.cursor() as cur:
                    cur.execute("RESET search_path")
            except psycopg.Error:
                # Connection likely unusable — let the pool reap it.
                pass
