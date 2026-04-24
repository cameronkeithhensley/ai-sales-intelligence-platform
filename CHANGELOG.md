# Changelog

All notable changes to this repository are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
