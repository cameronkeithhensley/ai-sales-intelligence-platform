# Module: waf

A regional AWS WAFv2 web ACL associated with the public ALB, stacked
with AWS-managed rule groups and a per-IP rate-based rule. Request logs
ship to a dedicated CloudWatch log group with sensitive headers
redacted.

## Why WAF at this layer

The ALB terminates TLS and is the single ingress into the platform's
HTTPS services. Attaching the WAF at the ALB means every inbound
request — to the dashboard, butler, or admin MCP — passes through the
same rule set before reaching any task. No service can accidentally
opt out, and adding the next service (Sprint 3 and beyond) does not
require any additional WAF wiring.

## Rule stack

| Priority | Rule | Purpose |
|---|---|---|
| 10 | `AWSManagedRulesCommonRuleSet` | OWASP Top 10 — XSS, local file include, generic bad bot fingerprints, oversized requests. The primary defensive layer. |
| 20 | `AWSManagedRulesKnownBadInputsRuleSet` | Catches Log4Shell-class payloads and other known-bad request bodies / URIs. |
| 30 | `AWSManagedRulesAmazonIpReputationList` | Source IPs Amazon has observed generating abuse traffic. |
| 40 | `AWSManagedRulesSQLiRuleSet` | Additional SQL-injection patterns beyond the CommonRuleSet baseline. |
| 100 | `RateLimitPerIp` | Rate-based rule, 2000 requests / 5-minute window per IP. |

The managed rule groups come from AWS and are kept up to date by the
AWS security team; this module subscribes the ACL to them rather than
re-implementing OWASP coverage. Individual sub-rules can be
count-instead-of-block via `managed_rule_groups[*].excluded_rules` when
a specific sub-rule false-positives on legitimate traffic (common
examples: body size limits too tight, or a noisy signature hitting a
specific dashboard endpoint).

## Why a rate-based rule

The platform fronts an agent API: an authenticated client can trigger
real work (LLM calls, third-party API calls, DB writes) on each
request. A credential-stuffing bot at a few hundred requests per second
will not just be annoying — it will spend real money. 2000 requests per
five minutes is ~6.7 req/sec sustained, which is generous for a
legitimate browser session and catches the obvious scripted abuse
pattern well below the threshold where an LLM budget gets ugly.

The rate-based rule aggregates by source IP. Bots coming in behind a
single IP are covered; distributed abuse is not, which is the gap that
the managed IP reputation list partially closes.

## Logging and header redaction

Request logs are sent to `aws-waf-logs-<env>-<name>` (the
`aws-waf-logs-` prefix is required by WAF's logging configuration).
Retention defaults to 30 days; tune per compliance / cost preference.

Three headers are redacted in the log stream: `authorization`,
`cookie`, and `x-api-key`. Leaving these in the logs would turn every
blocked request into a credential leak into CloudWatch. The rest of
the request — path, method, user-agent, matched rule, action — is
preserved, which is what you need for analysis.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `name`, `environment` | Naming. |
| `alb_arn` | ARN of the ALB to associate. |
| `rate_limit_per_5min` | Rate-based rule limit, default 2000. |
| `log_retention_days` | WAF log retention, default 30. |
| `managed_rule_groups` | List of `{name, priority, metric_name, excluded_rules}`. |
| `tags` | Additional tag merge. |

## Outputs (summary)

`web_acl_arn`, `web_acl_id`, `web_acl_name`, `log_group_arn`,
`log_group_name`.

## What this module does not do

- **Custom regex rules.** Callers who need them can either pass a
  custom `managed_rule_groups` entry pointing at an AWS-managed regex
  set, or extend the module with `aws_wafv2_regex_pattern_set`.
- **CloudFront coverage.** This is scoped `REGIONAL` for the ALB. If
  CloudFront is ever added in front, a second WAF (scoped
  `CLOUDFRONT`, in `us-east-1`) would attach there.
- **AWS Shield Advanced integration.** Out of scope; Shield Standard
  is automatic and free.
