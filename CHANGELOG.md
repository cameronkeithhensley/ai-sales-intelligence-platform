# Changelog

All notable changes to this repository are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Sprint 3] - 2026-04-24 — Agent scaffolding + MCP surface

### Added
- `agents/shared/{node,python}/` — runtime utilities implementing the four-part contract (pool + tenant routing, Cognito JWT, SQS consumer with visibility heartbeat, structured logging + redaction) once per runtime. 16 vitest tests + 22 pytest tests passing locally.
- `agents/shared/schema.json` — JSON Schema (draft 2020-12) for the SQS job envelope shared by every producer/consumer pair.
- `agents/admin-mcp/` — Express-mounted MCP server with six Zod-validated tool signatures (`dispatch_scout` / `dispatch_harvester` / `dispatch_profiler`, `write_outreach`, `get_job_status`, `get_signals`) and stub handlers. Every invocation writes a `public.audit_log` row.
- `agents/dashboard/` — Next.js 14 app-router skeleton with NextAuth wired to the Cognito provider, a portfolio-labelled landing page, and a custom Node server that preserves the Sprint 2 `/healthz` on 8080 contract.
- `agents/holdsworth/` — Express HTTP server with an HMAC-SHA256-verified `/webhooks/sms`, a JWT-guarded `/agent/message`, a heartbeat-only `scheduler.js` (deliberately named, *not* `cron.js`), and a ReAct-shaped agent-loop skeleton. Tools include `generate-message-draft` (no prompt content) and `record-outreach-event`.
- `agents/writer/` — SQS consumer wired to `@anthropic-ai/sdk`. The processor sends the sentinel string `[PROMPT CONTENT EXCLUDED FROM PUBLIC REPO]` on every call; a unit test asserts the sentinel remains unchanged so any future leak would fail CI.
- `agents/scout/` — asyncio Python SQS consumer with a generic `httpx` + BeautifulSoup `fetch` stub. No per-source extractors, no domain-specific selectors, no headless-browser automation.
- `agents/harvester/` — Python SQS consumer whose `adapters/__init__.py` ships a `DataAdapter` Protocol + an empty `REGISTRY` + `register`/`resolve`/`unregister` helpers. `resolve()` raises a `KeyError` whose message explicitly labels adapter implementations as proprietary.
- `agents/profiler/` — passive-DNS-only recon dispatcher with a hard-coded safe allowlist (`dns_lookup`, `whois`, `mx_records`). Unsafe tool names raise `ValueError`.
- `.github/workflows/app-validate.yml` — eslint + vitest across the Node services, ruff + pytest across the Python services. `workflow_dispatch` only.

### Safety
- Every file on the CLAUDE.md §2 IP denylist remains excluded (confirmed via forbidden-filename sweep).
- Writer contains no prompt content; the placeholder sentinel is the exact string an audit test asserts against.
- Harvester contains no adapter implementations — Protocol + empty registry only; the `adapters/README.md` states this explicitly.
- Holdsworth has no file named `cron.js`; the heartbeat stub is `scheduler.js` with an in-file comment noting scheduling / orchestration is proprietary.
- No workflow uses `aws-actions/configure-aws-credentials`.
- No references to any vendor name in the CLAUDE.local.md scrub list.

## [Sprint 2] - 2026-04-24 — Agent container infrastructure

### Added
- Terraform modules: `ecs-cluster`, `ecs-service`, `waf`, `guardduty`, `ses`, `s3` — each with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and a portfolio-grade `README.md`.
- Seven ECS services wired in `dev`: three load-balanced (`dashboard`, `holdsworth`, `admin-mcp`) behind the public ALB via host-based listener rules, and four workers (`scout`, `harvester`, `profiler`, `writer`).
- Dockerfiles and minimal stub entry points for all seven services. Node.js services (`dashboard`, `holdsworth`, `admin-mcp`, `writer`) use multi-stage `node:20-alpine`; Python services (`scout`, `harvester`, `profiler`) use `python:3.12-slim` (profiler uses `kalilinux/kali-rolling` for its passive OSINT toolchain).
- `migrations/` with four public-schema SQL migrations (`tenants`, `jobs`, `audit_log`, `outreach_events`) plus a README explaining the public-only scope and the bastion-based application path.
- Second CI workflow (`.github/workflows/container-validate.yml`) — hadolint matrix over all seven Dockerfiles plus a Trivy filesystem scan, gated on `workflow_dispatch` only.

### Safety
- No workflow uses `aws-actions/configure-aws-credentials`.
- Every task definition image reference uses the scrubbed account-id ECR URL via `module.ecr.repository_urls[...]`.
- Dockerfiles run as non-root; no vendor SDKs (SMS / email / CRM / people-data / OSINT) are referenced by name in `package.json` / `requirements.txt` / env vars.
- Only the four public-schema tables are in `migrations/` — per-tenant schema DDL remains proprietary and is not in this repo.

## [Sprint 1] - 2026-04-23 — Terraform foundation

### Added
- Terraform modules: `vpc`, `rds`, `bastion`, `sqs`, `ecr`, `secretsmanager`, `alb`, `cognito` — each with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and a portfolio-grade `README.md`.
- `terraform/environments/dev/` wiring all modules together with placeholder values.
- Repo-level `.tflint.hcl` (terraform recommended preset + aws ruleset).
- Offline CI workflow (`.github/workflows/terraform-validate.yml`) — `terraform fmt`, `terraform validate`, `tflint`, `checkov`. Gated on `workflow_dispatch` only.

### Safety
- Every `*.tfvars` uses `aws_account_id = "000000000000"` and `example.com` domain placeholders.
- `terraform/environments/dev/backend.tf` has the S3 + DynamoDB backend block commented out — no remote state is accessible from this repo.
- The AWS provider in the dev env pins `allowed_account_ids = [var.aws_account_id]` so an accidental credential from a real account is rejected at plan time.
- CI workflow does not configure AWS credentials; every job runs offline static analysis only.

## [Sprint 0] - 2026-04-23 — Repository foundation

### Added
- CLAUDE.md with sanitization and safety rules
- MIT LICENSE
- Expanded README with portfolio framing
- ARCHITECTURE.md (redacted)
- CONTRIBUTING.md
- docs/ skeleton and system architecture Mermaid
- CHANGELOG.md, PR template

### Fixed
- Moved concrete private scrub values (account IDs, domains, vendor names, private paths) out of committed `CLAUDE.md` and PR template into a new gitignored `CLAUDE.local.md`. The committed files now describe the scrub *structure* only.
- Removed incidental reference to the private database name from `docs/DATABASE.md`.
