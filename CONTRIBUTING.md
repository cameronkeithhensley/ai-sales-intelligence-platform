# Contributing

This is a portfolio repository — external contributions are not expected. These notes exist so that anyone (including future me or an AI coding assistant) can reproduce the local validation flow and understand how the repo is organized.

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Terraform | 1.5 |
| Node.js | 20 |
| Python | 3.12 |
| Docker | 24 |
| GitHub CLI (`gh`) | any recent |

No AWS credentials are required. **This repo does not deploy anything** — see `CLAUDE.md` §4 for the non-execution safeguards.

---

## Clone and validate offline

```bash
gh repo clone cameronkeithhensley/ai-sales-intelligence-platform
cd ai-sales-intelligence-platform

# Terraform — offline validation only (no backend, no AWS calls)
terraform -chdir=terraform/environments/dev init -backend=false
terraform fmt -check -recursive terraform/
terraform validate terraform/environments/dev

# Optional: lint / security scan
tflint --recursive terraform/
checkov -d terraform/

# Container lint (once Sprint 2 lands)
hadolint agents/*/Dockerfile

# App lint / tests (once Sprint 3 lands)
eslint agents/admin-mcp/
ruff check agents/scout/
pytest agents/scout/tests/
```

Any workflow under `.github/workflows/` runs the same offline tools and is gated on `workflow_dispatch` (manual trigger).

---

## Branching and PRs

- Work happens on a **sprint branch**: `sprint-0-foundation`, `sprint-1-terraform`, etc.
- PRs target `main` and are reviewed before merge.
- Commits are split by logical unit — docs, license, one module at a time, one workflow at a time. Squash-on-merge is **not** used for sprint branches because the commit sequence itself is part of the portfolio story.

---

## Ground rules for AI-assisted edits

See `CLAUDE.md` at the repo root. In short:

- No proprietary IP may enter this repo.
- Scrub rules (account id, domain, vendor names) apply to every commit.
- AWS non-execution safeguards are load-bearing — don't weaken them.
