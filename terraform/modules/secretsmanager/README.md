# Module: secretsmanager

Declares Secrets Manager containers for the platform. This module provisions
only the *shells* — it deliberately does not create `aws_secretsmanager_secret_version`
resources. Values are written out-of-band (via the AWS CLI, the console, a
separate controlled pipeline, or bootstrapping scripts) so that plaintext
secrets never appear in Terraform state.

## Why only the containers

Managing secret *values* in Terraform has two failure modes:

1. **The plaintext lands in tfstate.** Terraform state is a plaintext JSON
   file unless explicitly configured otherwise; a rogue developer, a
   misconfigured backend, or a state file leaked to a PR diff puts the
   password in the wrong hands.
2. **Rotation becomes a Terraform apply.** Rotating a secret shouldn't
   require a plan/apply cycle. Letting the value live in Secrets Manager
   and managing rotation through the SDK keeps secrets operations out of
   infrastructure change control.

Leaving values out of Terraform means:

- The first `terraform apply` creates empty secret containers.
- An operator populates values with `aws secretsmanager put-secret-value`
  (or via an imported one-shot bootstrap script).
- Rotation happens through Secrets Manager's rotation machinery, not
  through Terraform.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `secrets` | Map of logical name -> description. The description is what you see in the Secrets Manager console. |
| `path_prefix` | Leading path component. Default `/example-app`. |
| `recovery_window_in_days` | Delay between `DeleteSecret` and permanent deletion. Default 7; 0 forces immediate (destructive) deletion. |
| `kms_key_id` | Customer-managed KMS key ARN. Null falls back to `aws/secretsmanager`. |
| `environment` / `tags` | Tagging. |

## Outputs (summary)

`secret_arns`, `secret_ids`, `secret_names` — all maps keyed by the logical
name you passed in.

## Design choices

### Why ECS task definitions reference ARNs, not env vars

The ECS agent, given a `secrets` block in a task definition, retrieves the
secret at task startup and injects the value as an environment variable
visible only to the task process. The benefit:

- The task role must have explicit `secretsmanager:GetSecretValue` on the
  specific secret ARN. Privilege is enumerable.
- The secret value never appears in the task definition revision history,
  the CLI output, or CloudTrail (beyond the `GetSecretValue` event itself).
- Rotating the secret takes effect on the next task start — no task
  definition revision needed.

Contrast with plaintext `environment` blocks in a task definition, which
are visible to anyone with `ecs:DescribeTaskDefinition`.

### Path naming convention: `{path_prefix}/{env}/{name}`

Predictable paths let IAM policies use prefix wildcards. A task role can be
scoped to `arn:aws:secretsmanager:*:*:secret:/example-app/dev/*` so that a
leaked dev credential cannot read prod secrets. Using a flat namespace
(`my-app-db-password`, `my-app-jwt-key`) makes that scoping far harder.

Paths in this repo use `/example-app/{env}/{name}` since this is a public
portfolio; real deployments would set `path_prefix` to the actual app slug.

### `recovery_window_in_days = 7` (default)

When a secret is deleted, it enters a recovery window during which it can
be restored. Seven days is the minimum that still guards against a typo
like "oh I deleted the prod JWT signing key." Longer windows (up to 30
days) are fine; setting it to 0 is destructive and should be reserved for
throwaway dev secrets.

### Out-of-band value management

Typical operator flow after `terraform apply`:

```bash
aws secretsmanager put-secret-value \
  --secret-id /example-app/dev/anthropic-api-key \
  --secret-string "${ANTHROPIC_API_KEY}"
```

This keeps the actual key material in the operator's environment / vault
(1Password, etc.) and out of any repo.
