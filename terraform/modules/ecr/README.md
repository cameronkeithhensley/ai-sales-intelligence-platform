# Module: ecr

Provisions one ECR repository per agent/service, with the defaults a hosted
container registry should carry out of the box: immutable tags, scan-on-push,
AES-256 encryption at rest, and a lifecycle policy that keeps storage costs
from drifting up forever.

## Why one repo per service

A shared `ai-sales-intelligence` repo with every service pushing its own
tags would work, but it collapses three things that should stay separate:

- **IAM granularity.** One repo per service means the scout task role can
  be granted `ecr:BatchGetImage` on the scout repo and nothing else.
- **Scan result clarity.** Scan findings are per-repo; mixing services
  makes it harder to see which image is actually vulnerable.
- **Lifecycle reasoning.** Each service has its own release cadence. A
  per-repo lifecycle policy is easier to reason about than a shared one.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `repositories` | List of logical service names. Each entry becomes a repository `{environment}/{name}`. |
| `keep_last_tagged_count` | Lifecycle retention for tagged images. Default 20. |
| `expire_untagged_after_days` | Untagged images expire after this many days. Default 7. |
| `image_tag_mutability` | `IMMUTABLE` (default) or `MUTABLE`. |
| `environment` / `tags` | Tagging. |

## Outputs (summary)

`repository_urls`, `repository_arns`, `repository_names` — all maps keyed by
the logical service name — plus `registry_id` for constructing image URIs.

## Design choices

### `IMMUTABLE` tags

Immutable tags mean once `{service}:1.2.3` is pushed, it can never be
overwritten. This closes several footguns:

- A pipeline that re-pushes `:latest` on every build forces every consumer
  to pull a moving target, making rollbacks ambiguous.
- An attacker who compromises CI credentials cannot silently replace an
  already-deployed image tag with a malicious build.
- Rollbacks are deterministic: the tag `{service}:1.2.2` points at exactly
  what it pointed at yesterday.

If you need something that looks like `:latest`, use a sha-based tag
(`:{service}-{git-sha}`) and have deploy pipelines pin to it. "Latest" is a
deploy concern, not a registry concern.

### Scan on push

Every pushed image is scanned against the ECR vulnerability database
(Amazon Inspector-powered enhanced scanning is out of scope for this
module; that is an account-wide ECR setting). Findings are surfaced through
the ECR console and EventBridge.

### Lifecycle rationale

Two rules, applied in priority order:

1. **Keep the latest 20 tagged images.** Enough history for rollbacks and
   bisection; not so much that storage grows unbounded.
2. **Expire untagged images after 7 days.** Untagged images are typically
   leftovers from multi-stage builds or forcibly overwritten tags (which
   cannot happen here given immutability but can happen on migration).

Adjust both via module inputs for services with unusual cadence — e.g.
raise `keep_last_tagged_count` for infra-critical services where a 21-day
rollback window is desired.

### Encryption

`AES256` is the ECR-managed default and is plenty for public portfolio
work. Upgrade to `KMS` with a customer-managed key if audit requirements
demand per-repo key access control.
