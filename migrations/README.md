# Migrations

This directory holds SQL migrations for the **public (cross-tenant)**
schema only. Per-tenant schemas (one per tenant, created at onboarding,
dropped at offboarding — see [`docs/DATABASE.md`](../docs/DATABASE.md))
are deliberately not documented or versioned here; their DDL is
proprietary and managed outside this repository.

## What's in this directory

| File | Creates |
|---|---|
| `001_create_tenants.sql` | `public.tenants` — master tenant registry, with the `updated_at` trigger + tier / tenant_type CHECK constraints + unique index on `cognito_sub`. |
| `002_create_jobs.sql` | `public.jobs` (a.k.a. `job_results`) — async agent job tracking, with terminal-state integrity CHECK. |
| `003_create_audit_log.sql` | `public.audit_log` — append-only policy audit trail. `DELETE` is revoked from `PUBLIC`. |
| `004_create_outreach_events.sql` | `public.outreach_events` — outbound message audit for CAN-SPAM / telecom compliance. |

## Conventions

- **Numeric prefix is load order.** Migrations apply in lexicographic
  order: `001` before `002` before `003` before `004`. New migrations
  get the next unused number.
- **Idempotent.** Every migration uses `CREATE TABLE IF NOT EXISTS`,
  `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, and
  `ALTER ... DROP CONSTRAINT IF EXISTS` / `ALTER ... ADD CONSTRAINT`
  pairs so re-running the file is safe.
- **Each file is a single logical unit.** One table + its indexes +
  its constraints + its comments per file. If a change needs a new
  file, write a new migration; do not edit landed ones.
- **No down migrations.** Rolling back DDL in a multi-tenant Postgres
  is rarely what you actually want. Forward-only migrations with
  careful column defaults are the pattern.

## How migrations are applied

- **Production path:** migrations run from the bastion (see
  [`terraform/modules/bastion/README.md`](../terraform/modules/bastion/README.md))
  over an SSM Session Manager session. The operator `psql`s into RDS
  with the migration user, applies the next unapplied file, and
  records the application in the schema's own migrations table (an
  application-owned table, not declared here — the public-schema
  migrations are tracked by the application's own migration framework
  rather than by Terraform or a generic tool like Flyway).
- **CI does not run migrations.** No workflow in this repository has
  AWS credentials; a CI-driven migration would require that. Keeping
  migration application on the operator side is a deliberate trade:
  one fewer automated path that can move data, and an audit trail
  (`aws ssm start-session`) that lives in CloudTrail.

## What is not here

- Per-tenant DDL (prospect records, per-tenant configuration,
  conversation history, agent-specific caches).
- Policy catalogs (signal-type tables, strength weights, source
  legality tiers), which are populated by the application's own
  bootstrap flow.
- Seed data. Tenants are provisioned through the application, not
  through migrations.
