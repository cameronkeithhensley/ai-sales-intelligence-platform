# Module: guardduty

Enables AWS GuardDuty in the account/region with a 15-minute finding
publishing cadence, the S3 data-events feature on, and the Lambda
network-logs feature on. EKS audit logs are explicitly declared
`DISABLED` (not just omitted) so the decision to skip EKS coverage is
visible in state.

## What GuardDuty actually sees

GuardDuty is a managed threat-detection service that continuously
analyses three data sources without any agent or sidecar on the
workload:

1. **VPC flow logs** — detects port scans, SSH brute force, internal
   recon, and known-C2 egress from tasks. The `vpc` module already
   ships flow logs to CloudWatch for forensic use; GuardDuty reads a
   separate copy directly from the VPC service.
2. **CloudTrail management events** — detects unusual IAM actions
   (privilege escalation, key compromise patterns, disabled logging)
   and suspicious API call sequences.
3. **DNS logs** — detects DGA-generated queries, resolution of known
   malware domains, and DNS-tunnelling patterns from within the VPC.

With `enable_s3_logs = true`, it also consumes S3 data events
(per-object access) to detect exfil-style bucket reads and
anonymous-access attempts. With `enable_lambda_logs = true`, it
watches Lambda egress for connections to known-bad destinations —
useful insurance for the cost-aggregator Lambda.

## Why 15-minute finding frequency

`finding_publishing_frequency = "FIFTEEN_MINUTES"` is the lowest
available cadence. The cost difference against the one-hour and
six-hour settings is in the pricing-unit noise, and the latency
difference is real: a finding 15 minutes after a compromise is
actionable during a workday; a finding up to six hours later often
is not.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `environment` | Tagging only. |
| `enable_s3_logs` | S3 data events feature. Default `true`. |
| `enable_lambda_logs` | Lambda network logs feature. Default `true`. |
| `enable_eks_audit_logs` | Default `false`; this architecture does not run EKS. |
| `finding_publishing_frequency` | `FIFTEEN_MINUTES` / `ONE_HOUR` / `SIX_HOURS`. |
| `tags` | Additional tag merge. |

## Outputs (summary)

`detector_id`, `detector_arn`.

## What GuardDuty does not cover

GuardDuty is necessary but not sufficient. It does not see:

- **Application-layer abuse.** Credential stuffing against the
  dashboard, SQL injection payloads landing at a service endpoint,
  LLM prompt-injection against the writer. These are the WAF's (and
  the application's) responsibility — see `waf/`.
- **In-container behaviour.** GuardDuty does not run inside a task.
  A compromised container executing shell commands is visible to
  GuardDuty only through its network behaviour (flow logs, DNS); it
  does not see process trees or file-system access. Container
  runtime monitoring would need a different tool (e.g. Amazon
  Inspector's runtime monitoring add-on, out of scope here).
- **Business-logic anomalies.** A tenant exfiltrating via legitimate
  API calls looks normal to GuardDuty. Rate limits, audit logs, and
  tenant-scoped IAM are the application-level answer.

Pairing GuardDuty with the WAF and with `audit_log` at the database
layer gives overlapping visibility: WAF for public-ingress patterns,
GuardDuty for cloud-control-plane and network patterns, audit_log for
business-logic events.

## What this module does not do

- **Cross-account member aggregation.** The commented-out path in the
  original scope (an `aws_guardduty_member` block) is appropriate for
  a security-tooling account in an AWS Organizations setup. This
  single-account portfolio does not need it; add when multi-account
  arrives.
- **Automated response.** Hooking findings into EventBridge → Lambda
  → remediation actions belongs in an operations module, not in the
  detector module. Keep detection and response separately ownable.
