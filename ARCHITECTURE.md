# Architecture

> Redacted architecture reference for the AI Sales Intelligence Platform. This document captures the **shape** of the system — services, data flow, multi-tenancy, security, and deployment — without describing the proprietary signal catalog, pipeline sequencing, scoring, prompt engineering, or vendor-specific adapter details that make the production system commercially differentiated.

---

## 1. System overview

The platform is a multi-tenant SaaS that automates the top of an outbound sales funnel. Each tenant is an individual sales team or small business. The system ingests public data, builds prospect context, drafts personalized outreach, and delivers it through messaging channels, with a conversational AI agent as the customer-facing interface.

The design decomposes the workload into **specialized async agents** behind a shared AWS footprint:

- A **conversational butler** handles inbound customer messaging and scheduled jobs.
- An **operator MCP server** exposes internal orchestration tools over the Model Context Protocol.
- Four **worker agents** (Scout, Harvester, Profiler, Writer) consume SQS jobs and write results to a shared result table.

All services are containerized, share a single VPC, and run on ECS Fargate.

---

## 2. AWS services and their roles

| Service | Role |
|---|---|
| **ECS Fargate** | Hosts every long-running service (agents, dashboard, MCP server). Serverless containers keep per-service ops to Dockerfile + task definition. |
| **Application Load Balancer** | Single public ingress. Host-based and path-based routing splits traffic across dashboard / butler / operator surfaces. TLS terminates here. |
| **WAF** | Attached to the ALB. Rate limiting, managed rule groups, per-host rules. |
| **RDS PostgreSQL (+ PostGIS)** | Primary data store. PostGIS is used for geographic queries on tenant-scoped prospect data. |
| **SQS** | Decouples the orchestrator from worker agents. One queue per agent role, each with a DLQ and bounded retries. |
| **Cognito** | OIDC identity provider. Issues JWTs that every service validates at the edge and on direct-DB paths. |
| **Secrets Manager** | Holds database credentials, JWT signing material, and third-party API keys. Task definitions reference secrets by ARN — no secrets on disk, no secrets in env files in git. |
| **ECR** | Private container registry for every agent image. Image tags are immutable per deploy. |
| **GuardDuty** | Account-wide threat detection. Findings flow to an alerting pipeline. |
| **Lambda** | Used for scheduled / event-driven utilities outside the long-running agent fleet (e.g. cost aggregation). |
| **S3** | Artifact and export storage, per-tenant prefix isolation. |
| **SES** | Transactional email out of the butler agent (notifications, system mail). Customer-facing bulk outreach goes through a dedicated email delivery provider. |

---

## 3. Data-flow pattern — SQS job dispatch → agent consumers

The system treats every non-trivial unit of work as an **async job**. Producers never block on workers.

```
┌─────────────┐     enqueue      ┌───────────────┐
│  Butler     │ ───────────────▶ │  Agent SQS    │
│  MCP Server │                  │  queue        │
└─────────────┘                  │  (+ DLQ)      │
                                 └──────┬────────┘
                                        │ long-poll
                                        ▼
                                 ┌───────────────┐
                                 │  Agent worker │
                                 │  (ECS task)   │
                                 └──────┬────────┘
                                        │ write
                                        ▼
                                 ┌───────────────┐
                                 │  job_results  │
                                 │  (Postgres)   │
                                 └───────────────┘
```

### Job lifecycle

1. A producer (butler or operator MCP tool) inserts a row into `job_results` with `status='pending'` and enqueues a message on the appropriate agent's SQS queue.
2. The agent long-polls its queue, claims the job, flips the row to `status='running'`, and records `started_at`.
3. On success the agent writes its output into the row's `result` JSONB column and sets `status='completed'`. On failure it records an error and retries up to the queue's max-receive threshold.
4. Messages that exceed the threshold land in the DLQ for manual review — they never disappear silently.
5. Callers (butler, dashboard) poll `job_results` by `job_id` to observe completion.

This pattern gives each agent its own scaling profile, isolates failures, and keeps the producer latency-insensitive to long-running external API calls.

### Why four queues, not one

Each agent has very different rate-limit, fan-out, and cost characteristics. Separate queues mean back-pressure on one agent (e.g. an external API outage) does not starve the others, and per-queue alarms map cleanly to per-agent SLOs.

---

## 4. Multi-tenancy — schema-per-tenant in PostgreSQL

Tenant isolation is enforced at the **database schema** level.

- **Cross-tenant tables** live in the `public` schema — `tenants`, `jobs` (a.k.a. `job_results`), `audit_log`, `outreach_events`. These are read/written by every service.
- **Per-tenant tables** live in a dedicated schema named after the tenant — prospect records, conversation history, tenant-specific configuration. Each tenant schema has the same DDL shape.
- Each tenant has a **PostgreSQL role** scoped to their own schema plus read-only access to the cross-tenant tables they need.
- The `tenants` table maps Cognito `sub` → tenant UUID → schema name. Services resolve the caller's tenant from the JWT before any data access.
- The `audit_log` table is append-only and stripped of `DELETE` permission for tenant-scoped roles, so policy-enforcement events are preserved even under SQL misuse.

### Why schema-per-tenant (and not row-level filtering)

- Tenant schemas can be dropped cleanly at offboarding with no cross-tenant leak risk.
- A forgotten `WHERE tenant_id = …` clause cannot accidentally expose another tenant's data because the role cannot see other schemas.
- PostgreSQL handles schemas efficiently at the scale this system targets (low thousands of tenants). Past that, the pattern would need revisiting.

---

## 5. Security design

### Identity and authentication

- **Cognito User Pools** issue JWTs via the OIDC authorization code flow with PKCE. Google OIDC is federated in for SSO.
- Every service validates incoming JWTs against the Cognito JWKS — signature, issuer, audience, expiration. No service trusts a header alone.
- The butler agent additionally authenticates inbound webhook traffic from the SMS provider via signature verification before acting on the message.

### Authorization

- Tenant identity is **derived from the JWT**, never accepted as a request parameter.
- Operator MCP tools that span tenants require an explicit operator role claim.
- Database roles scope per-tenant DML to the tenant's own schema (see §4).

### Network

- All services run in private subnets. Only the ALB has public ingress.
- A bastion host (SSM Session Manager only — **no SSH key**) is the sole path to the database for migrations and ad-hoc ops.
- Security groups are least-privilege: agent tasks can talk to RDS and SQS and nothing else.
- **WAF** on the ALB handles rate limiting and managed rule groups (OWASP top 10, bad bots).
- **GuardDuty** monitors VPC flow logs and CloudTrail for account-level threats.

### Secrets

- Every secret (DB credentials, JWT signing material, third-party API keys) lives in AWS Secrets Manager.
- ECS task definitions reference secrets by ARN; containers receive them as environment variables at launch.
- No secret is ever committed to this or any other repo. This repo is scrubbed of any such material by construction (see `CLAUDE.md`).

### Least-privilege IAM

- Each ECS service has its own task role. A service can read only the SQS queues and Secrets Manager paths it needs; it can write only to its own queue outputs and its own schema.
- The OIDC trust between GitHub Actions and the real AWS account is scoped by repository + branch + environment.
- **This public repo is deliberately not wired to that trust** — no workflow may use `aws-actions/configure-aws-credentials`. See `CLAUDE.md` §4.

---

## 6. Deployment model — GitOps via GitHub Actions

The live system follows a standard GitOps pattern. **This public repo demonstrates the pattern but never executes it.**

### Pipeline shape (reference)

1. PR opens → `terraform fmt`, `terraform validate`, `tflint`, `checkov`, container lint (`hadolint`, `trivy`), language lint and tests all run offline.
2. PR merges to `main` → build container images, push to ECR, run `terraform plan` against the target environment.
3. Manual approval → `terraform apply` updates the ECS service with the new image tag.
4. Health checks on the ALB target group gate the rollout.

### Per-environment parameterization

- Three environments: **dev**, **staging**, **prod**, each with its own Terraform state and workspace.
- Each environment has a `terraform.tfvars` that sets `aws_account_id`, `domain_name`, instance sizes, and feature flags.
- Secrets differ per environment (separate Secrets Manager paths).
- The public repo ships every `tfvars` with **placeholder values** (account id `000000000000`, domain `example.com`) so nothing in this repo could be applied against a real account.

### Why GitOps

- Every infrastructure change is code-reviewed and auditable via `git log`.
- Drift is detectable via `terraform plan` — if the plan is non-empty on `main`, something changed out of band.
- Rollback is a `git revert` + re-apply, not a console click.

---

## 7. Out of scope for this document

These concerns are part of the production system but are intentionally **not** described here:

- Signal-type catalogs or strength weights.
- Pipeline pass sequencing, scheduling, or quota logic.
- Scoring, ranking, or decision-maker resolution rules.
- Vendor-specific API adapter implementations, endpoints, or payload shapes.
- Pricing, zoning, or serviceable-area rules.
- LLM prompts, tone matrices, or outreach templates.
- Customer-facing UX specifics.

Future sprints in this repo will add Terraform, container scaffolding, and the MCP tool surface — always keeping the exclusions above in mind.
