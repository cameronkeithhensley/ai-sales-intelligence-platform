# Terraform

This directory holds the infrastructure-as-code for the AI sales intelligence
platform: a library of reusable modules under `modules/` and one directory per
deployment environment under `environments/`. Each environment composes the
modules with its own inputs — VPC CIDRs, instance sizes, domain names, backup
retention, and similar knobs — so the same module code serves `dev`, future
`staging`, and future `prod` without duplication. `dev` is wired up in this
sprint; `staging` and `prod` are planned for later sprints.

This is a **portfolio repository** and cannot provision AWS resources. Every
`*.tfvars` file uses `aws_account_id = "000000000000"` and placeholder domains.
Each environment's `backend.tf` has its `s3` + `dynamodb` block commented out,
so no remote state is ever reachable from here. The CI workflow runs
`terraform fmt`, `terraform validate`, `tflint`, and `checkov` in offline mode
only — there is no `aws-actions/configure-aws-credentials` step anywhere. See
[`CLAUDE.md` §4](../CLAUDE.md) for the full non-execution safeguards.
