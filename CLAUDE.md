# CLAUDE.md — Ground rules for Claude Code sessions in this repo

This is a **public portfolio repository**. It showcases multi-tenant AWS / Terraform / CI-CD patterns drawn from a private production SaaS. A separate, gitignored file — `CLAUDE.local.md` — holds the concrete private values (account IDs, domains, vendor names, absolute paths) referenced by the scrub rules below. Claude Code sessions in this repo must load **both** files.

If `CLAUDE.local.md` is missing, treat every candidate value as "scrub unless explicitly safe" and ask the operator rather than guessing.

---

## 1. Purpose and boundaries

- **Goal:** demonstrate architecture, infrastructure, and CI-CD patterns — not deliver a working system.
- **Non-goal:** this repo is **structurally incapable of provisioning AWS resources**. Any change that would enable real cloud deployment is a bug.
- **Audience:** hiring managers, technical reviewers, and future employers reading public code.

---

## 2. IP denylist — never read, copy, reference, or paraphrase

Treat these categories of files in the private source tree as if they do not exist:

- Orchestration and scheduling logic (cron, quota, pipeline sequencing, feature flags, pipeline status).
- Scoring, ranking, decision-maker, and contact-selection logic.
- Any OSINT / contact / neighbor / homeowner discovery or enrichment module.
- All LLM prompts, tone matrices, and outreach templates.
- All third-party API adapter implementations. The registry / index file may be referenced **structurally only** (its existence, not its contents).
- All signal-type catalogs, strength weights, business-category or pipeline-rule JSON.
- All cost-aggregator implementation logic.
- Any `.env` or `.env.*` file.
- Anything containing customer data, non-public tenant schemas, or API keys.

The concrete file paths matching these categories live in `CLAUDE.local.md`.

**If a file's purpose is unclear, skip it.** Do not read speculatively. Denylist-adjacent files should be treated as denylisted until confirmed safe.

---

## 3. Scrub rules — apply to everything copied or referenced

Apply these substitutions to any value that makes it into this repo (commit messages, code, docs, diagrams, tfvars, example configs):

### Identifiers

| Category | Public replacement |
|---|---|
| AWS account IDs | `000000000000` |
| Real domains and subdomains | `example.com` (or `dev.example.com`, `staging.example.com`) |
| Secrets Manager path prefixes | `/example-app/...` |
| Real emails, phone numbers, person names | removed or generic (`user@example.com`, `+10000000000`) |
| **Exception:** "Cameron Hensley" is permitted in author, copyright, and footer lines. |

The actual private identifier values that must be scrubbed are listed in `CLAUDE.local.md`.

### Vendor names → generic labels

| Category | Public replacement |
|---|---|
| SMS / voice provider | SMS provider |
| Bulk email delivery provider | email delivery provider |
| Person-data / people-search API | person-data API |
| Property / parcel / real-estate API | property-data API |
| Contact email / phone enrichment provider | contact enrichment provider |
| Passive OSINT / recon tool | OSINT passive recon tool |
| Paid social / search ad platform | ad platform API |
| Sales CRM | CRM provider |
| Review / local listing platform | review platform API |
| Payment processor | payment provider |

The actual vendor names that map into each category are listed in `CLAUDE.local.md`.

### Keep explicit (these are industry-standard, non-proprietary)

AWS (all services by name), Terraform, Anthropic, PostgreSQL, PostGIS, Next.js, Node.js, Python, Docker, GitHub Actions.

---

## 4. AWS non-execution safeguards (CRITICAL)

A live OIDC trust exists between GitHub and a real AWS account. This repo must never be able to use it.

- Every `*.tfvars` file uses `aws_account_id = "000000000000"` and domain placeholders.
- Every Terraform environment's `backend.tf` is either **absent** or has the `s3` / `dynamodb` backend block **commented out**.
- **No workflow may use `aws-actions/configure-aws-credentials`.** Not even for plan. Not even read-only.
- All workflows are gated on `workflow_dispatch` (manual only — no `push`, no `pull_request` triggers) until explicitly enabled.
- Workflows may run offline-only tools: `terraform fmt`, `terraform validate`, `tflint`, `checkov`, `trivy`, `hadolint`, `eslint`, `ruff`, `pytest`.
- If a workflow demonstrates `terraform plan`, it must use `terraform init -backend=false` so nothing touches remote state or the AWS API.

A change that weakens any safeguard above requires explicit approval from Cameron in the PR.

---

## 5. Workflow conventions

- All work happens on a sprint branch (e.g. `sprint-0-foundation`, `sprint-1-terraform`).
- Claude opens a PR to `main`; Cameron reviews and merges. Claude does **not** merge.
- Commits are split by logical unit (docs, license, terraform module, workflow, etc.) — not squashed at commit time.
- The sprint plan is:
  - Sprint 0 — repository foundation (this sprint)
  - Sprint 1 — Terraform foundation (modules, environments, non-executing plan workflow)
  - Sprint 2 — agent container and service infrastructure
  - Sprint 3 — agent scaffolding and Admin MCP server

---

## 6. Pre-commit self-check

Before every commit, verify:

1. No values from the `CLAUDE.local.md` scrub tables appear anywhere in the staged diff.
2. No file from the IP denylist is referenced, copied, or paraphrased.
3. No `aws-actions/configure-aws-credentials` in any workflow.
4. All `backend.tf` blocks are commented or absent.
5. No `push` / `pull_request` workflow triggers.

If any check fails, fix it before committing.
