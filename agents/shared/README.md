# agents/shared

Contract shared by every agent service in this repository. A service is
considered a well-behaved member of the platform when it: (1) consumes
SQS job messages whose envelopes validate against
[`schema.json`](./schema.json), (2) verifies the caller's Cognito
access token at every ingress surface and attaches the resolved claims
to the request, (3) reaches Postgres through the shared pool and runs
every per-tenant query inside a `withTenant` / `with_tenant` scope that
pins `search_path` to the caller's schema, and (4) emits structured
JSON logs with the shared redaction list applied so known-secret
environment variables never leak into CloudWatch.

Two runtime implementations of the contract live alongside this
README: [`node/`](./node) for the Node.js services (dashboard,
holdsworth, admin-mcp, writer) and [`python/`](./python) for the
Python workers (scout, harvester, profiler). Each implements the same
five primitives — config loading, pool + tenant routing, JWT
verification, SQS consumer with visibility-timeout heartbeat, and
structured logging — in the idiomatic form for its runtime. Services
depend on their runtime's shared package and nothing else from this
directory; the two implementations are deliberately parallel rather
than cross-calling.
