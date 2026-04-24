# Module: rds

A single-instance PostgreSQL RDS primitive with the guardrails a portfolio or
production workload should never be missing: encryption at rest, TLS enforced at
the parameter-group level, IAM database authentication enabled, Performance
Insights on, Postgres logs exported to CloudWatch, private subnet placement, and
master credentials stored in Secrets Manager — not floating around as
environment variables.

## Why this shape

Most tutorials wire up an `aws_db_instance` with `publicly_accessible = true`,
no parameter group, and the password hard-coded in a tfvars file. That pattern
cannot pass any serious security review and teaches the wrong habits. This
module bakes the correct defaults in and makes opting out explicit.

## Schema-per-tenant

The larger platform uses a schema-per-tenant model with PostGIS for geospatial
signals. That model is documented in [`docs/DATABASE.md`](../../../docs/DATABASE.md);
this module provisions the instance layer. Tenant onboarding creates the
per-tenant schema at the application layer, not via Terraform, so that onboarding
runs on application time, not infrastructure deploys.

The `postgis` extension is installed via `CREATE EXTENSION` in the migrations
that the app runs from the bastion — the RDS parameter group loads
`pg_stat_statements` only, since PostGIS does not require a preload.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `engine_version` / `parameter_group_family` | Keep these aligned (`15.4` ↔ `postgres15`). |
| `instance_class` | `db.t3.micro` in dev; larger for prod. |
| `allocated_storage` / `max_allocated_storage` | Autoscaling upper bound. Set equal to disable. |
| `multi_az` | Synchronous standby in a second AZ. Off in dev, on in prod. |
| `backup_retention_period` | `0` disables automated backups. |
| `deletion_protection` | Set `true` for prod. Disables skip_final_snapshot. |
| `db_subnet_ids` | Private subnets from the `vpc` module. Must span ≥ 2 AZs. |
| `allowed_security_group_ids` | The bastion SG + ECS task SG go here. |
| `vpc_id` | For the DB security group. |
| `kms_key_id` | Customer-managed KMS key; `null` falls back to the AWS-managed RDS key. |
| `master_password_secret_arn` | When non-null, the module reads the password from this Secrets Manager secret. When null, the module generates a 32-char password and stores it in a secret it manages. |
| `db_name` | Optional initial database name. |

## Outputs (summary)

`endpoint`, `address`, `port`, `db_instance_arn`, `db_instance_id`,
`db_instance_resource_id` (for IAM auth policy), `security_group_id`,
`parameter_group_name`, `master_password_secret_arn`.

## Design choices

### TLS is enforced at the database, not hoped for at the client

`rds.force_ssl = 1` in the parameter group causes the server to refuse
unencrypted connections. A misconfigured client cannot silently fall back to
cleartext. The parameter group ships with the instance rather than being a
separate deploy.

### `pg_stat_statements` is always on

It is the first tool you reach for when diagnosing slow queries and it is
cheap. Loading it requires a reboot, which is why it is marked
`apply_method = "pending-reboot"`: the module will not surprise-reboot a
live instance on a config change.

### IAM database authentication is enabled

With `iam_database_authentication_enabled = true`, application roles can
request short-lived DB auth tokens from STS instead of holding a long-lived
password. Combined with the task role's policy, this eliminates a standing
credential from the running task's environment entirely. The master password
still exists as a break-glass; it lives in Secrets Manager.

### Performance Insights + CloudWatch log exports

`postgresql` and `upgrade` logs are exported to CloudWatch, and Performance
Insights is enabled with 7-day retention (free tier). These are the two
observability primitives you want on by default — having to wait until an
incident to enable them defeats the purpose.

### Encryption at rest

`storage_encrypted = true` is non-negotiable. If `kms_key_id` is null, RDS
uses the AWS-managed default RDS key; for production, supply a customer-managed
KMS key so that key access can be scoped and audited alongside the instance.

### Master password handling

Two modes, both of which avoid plaintext passwords:

- **Caller-supplied secret** (`master_password_secret_arn` set). The module
  reads the secret at plan time via a data source. The preferred pattern —
  credentials are rotated outside Terraform.
- **Module-managed** (`master_password_secret_arn = null`). The module
  generates a 32-character password, stores it in a Secrets Manager secret at
  `/${environment}/${identifier}/master-password`, and writes the first
  version. `ignore_changes = [password]` keeps out-of-band rotations from
  registering as drift.

In both modes the secret's ARN is exposed as a module output so downstream
modules (bastion, ECS task definitions) can reference it without ever holding
the plaintext password.

### Bastion-only access path

The security group allows ingress only from explicitly permitted SGs (bastion,
ECS tasks). There is no `0.0.0.0/0` rule and the instance is in private
subnets with `publicly_accessible = false`. Migrations run from the bastion
via SSM Session Manager (see `bastion/`), which gives a full CloudTrail audit
trail with no SSH keys to rotate.
