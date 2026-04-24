# Deployment

> This document describes the deployment model of the **live** AI Sales Intelligence Platform. **This public portfolio repository does not deploy.** See `CLAUDE.md` §4 for the specific safeguards that make deployment structurally impossible from this repo.

---

## Model: GitOps via GitHub Actions

Every environment is provisioned and updated through GitHub Actions. There is no local `terraform apply`, no console-driven change, and no out-of-band infrastructure edit. If it is not in `main`, it is not in production.

1. **PR opens** → offline validation runs: `terraform fmt`, `terraform validate`, `tflint`, `checkov`, container lint (`hadolint`, `trivy`), language lint, and unit tests.
2. **PR merges to `main`** → a build workflow packages container images, pushes them to ECR, and runs `terraform plan` against the target environment.
3. **Manual approval** (GitHub environment protection rule) → `terraform apply` updates the ECS service.
4. **Health gate** → ALB target group health checks must pass before the rollout completes.

The GitHub ↔ AWS trust is OIDC-based — no long-lived AWS keys are stored in GitHub secrets.

---

## Environments

| Environment | Purpose | Notes |
|---|---|---|
| **dev** | Active development and integration. Smallest instance sizes, non-durable data, permissive feature flags. |
| **staging** | Release candidate validation. Production-shaped infrastructure at reduced scale. Used for load and integration testing before prod cutover. |
| **prod** | Customer-facing. Strict change-control via GitHub environment protection. |

Each environment has:

- Its own Terraform state (separate remote backend).
- Its own `*.tfvars` setting account id, domain, instance sizes, and feature flags.
- Its own Secrets Manager paths (no shared secrets across environments).
- Its own ECR repository tags.

---

## Per-environment parameterization

Infrastructure differences between environments live in `terraform/environments/<env>/terraform.tfvars`. The module code in `terraform/modules/` is environment-agnostic.

Typical variables driven per-environment:

- `aws_account_id`, `aws_region`
- `domain_name` (e.g. `dev.example.com`, `staging.example.com`, `example.com`)
- RDS instance class and storage size
- ECS task CPU / memory and desired count
- Feature flags (e.g. whether to expose the dashboard publicly, whether bulk outreach is enabled)

---

## Explicit note — this repo does not deploy

This repository is a **portfolio** showing the shape of the deployment pipeline:

- Every `*.tfvars` in this repo uses `aws_account_id = "000000000000"` and `example.com` domains.
- Every `backend.tf` is either absent or commented out — no remote state is accessible.
- No workflow uses `aws-actions/configure-aws-credentials`.
- All workflows are gated on `workflow_dispatch` only.
- Any `terraform plan` demonstration uses `terraform init -backend=false`.

If you fork this repo, it will not be able to touch an AWS account without deliberate, multi-step configuration changes.
