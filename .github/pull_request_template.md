<!-- Title convention: "Sprint N: <short description>" -->

## Sprint

- [ ] Sprint 0 — repository foundation
- [ ] Sprint 1 — Terraform foundation
- [ ] Sprint 2 — agent container infrastructure
- [ ] Sprint 3 — agent scaffolding + MCP
- [ ] Other: <!-- specify -->

## Summary

<!-- 1–3 bullets: what this PR does and why. -->

## Files changed

<!-- Paste a summary — e.g. "Added LICENSE, ARCHITECTURE.md; replaced README.md; …" -->

## Validation commands run

<!-- Paste the commands you ran locally and whether they passed. -->

```
terraform fmt -check -recursive terraform/
terraform validate terraform/environments/dev
tflint --recursive terraform/
```

## Manual review checklist

### IP-leak check
- [ ] No file from the IP denylist (see `CLAUDE.md` §2 and `CLAUDE.local.md`) was read, copied, or paraphrased.
- [ ] No proprietary signal-type names, pipeline-pass sequencing, scoring rules, or prompt content appear in the diff.
- [ ] No private vendor names appear — all third-party providers use the generic labels from `CLAUDE.md` §3.
- [ ] No real customer data, emails, phone numbers, or person names (other than "Cameron Hensley" in author lines).

### AWS non-execution safeguards
- [ ] All `*.tfvars` use `aws_account_id = "000000000000"` and `example.com` / placeholder domains.
- [ ] Every `backend.tf` is absent or has its backend block commented out.
- [ ] No workflow uses `aws-actions/configure-aws-credentials`.
- [ ] All workflows are gated on `workflow_dispatch` only — no `push` / `pull_request` triggers.
- [ ] Any `terraform plan` demonstration uses `terraform init -backend=false`.

### Scrub check
- [ ] Every private identifier (account ID, domain, secrets path, database name) has been replaced with its public placeholder per `CLAUDE.md` §3 and `CLAUDE.local.md`.

## Notes for the reviewer

<!-- Anything that needs context, design justification, or follow-up. -->
