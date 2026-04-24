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

<!-- Paste a summary — e.g. "Added CLAUDE.md, LICENSE, ARCHITECTURE.md; replaced README.md; …" -->

## Validation commands run

<!-- Paste the commands you ran locally and whether they passed. -->

```
terraform fmt -check -recursive terraform/
terraform validate terraform/environments/dev
tflint --recursive terraform/
```

## Manual review checklist

### IP-leak check
- [ ] No file from the CLAUDE.md IP denylist was read, copied, or paraphrased.
- [ ] No proprietary signal-type names, pipeline-pass sequencing, scoring rules, or prompt content appear in the diff.
- [ ] No real vendor names from the scrub table appear (Twilio, Instantly.ai, PDL, ATTOM, Apollo, Hunter, SignalHire, Lusha, Shodan, theHarvester, Facebook/Google Ads, HubSpot/Salesforce/Pipedrive, Yelp/Google Places, Stripe).
- [ ] No real customer data, emails, phone numbers, or person names (other than "Cameron Hensley" in author lines).

### AWS non-execution safeguards
- [ ] All `*.tfvars` use `aws_account_id = "000000000000"` and `example.com` / placeholder domains.
- [ ] Every `backend.tf` is absent or has its backend block commented out.
- [ ] No workflow uses `aws-actions/configure-aws-credentials`.
- [ ] All workflows are gated on `workflow_dispatch` only — no `push` / `pull_request` triggers.
- [ ] Any `terraform plan` demonstration uses `terraform init -backend=false`.

### Scrub check
- [ ] Account id `429260466248` → `000000000000` everywhere.
- [ ] `intentsignaler.com` (and subdomains) → `example.com`.
- [ ] Secrets Manager paths `/intent-signaler/...` → `/example-app/...`.

## Notes for the reviewer

<!-- Anything that needs context, design justification, or follow-up. -->
