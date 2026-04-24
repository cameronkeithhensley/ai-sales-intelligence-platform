# Module: ecs-service

The reusable workhorse. One module that knows how to stand up either a
public-facing, load-balanced Fargate service (dashboard / butler / admin
MCP) or a back-of-house worker (scout / harvester / profiler / writer)
with the same IAM, logging, networking, and deployment-safety defaults.
Callers flip one variable — `load_balancer_enabled` — to choose.

## Why one module, two modes

The dashboard, butler, and admin MCP are "services with an ingress": the
ALB needs a target group, the listener needs a rule, the task SG needs
ALB-sourced ingress. The workers are "services without an ingress": no
target group, no listener rule, no SG ingress rule. Everything else —
task definition, IAM, logs, circuit-breaker deployments, private subnets,
Secrets Manager injection — is identical.

Splitting this into two modules would duplicate ~250 lines of HCL and
encourage divergence; bundling it behind one flag keeps every service
on the same IAM story and the same deploy semantics.

## Inputs (summary)

Common:

| Name | Purpose |
|---|---|
| `service_name`, `environment`, `cluster_id`, `image_url` | Identity + where it runs. |
| `container_port`, `cpu`, `memory`, `desired_count` | Task shape. |
| `vpc_id`, `private_subnet_ids` | Networking. |
| `env_vars` | Non-secret env, as a map. |
| `secret_arns` | Map of env var name -> Secrets Manager ARN. |
| `log_retention_days` | CloudWatch Logs retention, default 30. |
| `additional_task_role_policy_arns` | Extra task-role policy attachments. |
| `enable_execute_command` | Toggles ECS Exec. |
| `capacity_provider_strategy` | Override to pin onto `FARGATE_SPOT`. |

Load-balanced mode (when `load_balancer_enabled = true`):

| Name | Purpose |
|---|---|
| `alb_https_listener_arn`, `alb_security_group_id` | Wiring into the shared ALB. |
| `host_header`, `path_patterns` | Listener rule match conditions. |
| `listener_rule_priority` | Must be unique across all rules on the listener. |
| `health_check_path`, `health_check_grace_period_seconds`, `deregistration_delay_seconds` | Target-group tuning. |

## Outputs (summary)

Always: `service_name`, `service_id`, `task_definition_arn`,
`task_definition_family`, `security_group_id`, `task_role_arn`,
`task_role_name`, `execution_role_arn`, `log_group_name`.

When load-balanced: `target_group_arn`, `listener_rule_arn`. Both are
`null` for worker services so callers can `try(...)` or conditionally
reference them.

## Design choices

### Two IAM roles, two distinct jobs

- **Task execution role** (`{env}-{service}-exec`): used by the ECS
  agent during task startup. Pulls the image from ECR, pulls secrets
  from Secrets Manager, and writes to CloudWatch Logs. The scope is
  narrow: the module attaches `AmazonECSTaskExecutionRolePolicy` plus a
  `secretsmanager:GetSecretValue` policy scoped to exactly the ARNs in
  `secret_arns`. Nothing else belongs here.
- **Task role** (`{env}-{service}-task`): used by the *running*
  container. Starts with a logs-write scope on the service's own log
  group and accepts additional policy attachments via
  `additional_task_role_policy_arns`. Per-service SQS / S3 / DynamoDB
  permissions belong on this role, attached from the module that owns
  the target resource (e.g. an IAM policy defined next to the SQS queue
  that the service reads from).

Keeping these two roles distinct is the whole point: a compromised
container gets the *task* role's permissions, not the *execution*
role's. Merging them is a known anti-pattern that gives an attacker the
ability to read every secret referenced by the service at startup, not
just the ones the app legitimately uses.

### Secrets go in the `secrets` block, never in `environment`

The container definition has two fields: `environment` (plain strings)
and `secrets` (references to Secrets Manager / Parameter Store). They
look identical at runtime — both surface as env vars inside the
container — but their lifecycle is very different:

- `environment` values are written into the task definition revision in
  plaintext. Anyone with `ecs:DescribeTaskDefinition` can read them.
  They appear in `aws ecs describe-task-definition` output, in Terraform
  plan diffs, and in CloudTrail.
- `secrets` values are resolved by the ECS agent from the referenced
  ARN at task startup. The task definition holds only the ARN, never
  the value. Rotating the secret takes effect on the next task start
  without a new task-definition revision.

The module enforces this split by taking separate `env_vars` and
`secret_arns` variables. There is no escape hatch to put a secret into
`env_vars` accidentally.

### Deployment circuit breaker + rollback

`deployment_circuit_breaker { enable = true, rollback = true }` tells
ECS to watch a new deployment for unhealthy tasks and automatically roll
back to the previous task-definition revision if it cannot stabilize.
This is the difference between "I pushed a broken image and traffic
broke" and "I pushed a broken image, the deployment stalled, ECS rolled
back, traffic is fine, here is the CloudWatch event to investigate."

Paired with `deployment_maximum_percent = 200` and
`deployment_minimum_healthy_percent = 50`, a new deployment gets enough
room to spin up alongside the old one before draining it — no
blue/green orchestrator needed.

### Target group health-check tuning

- `healthy_threshold = 2`, `unhealthy_threshold = 3`: a task has to fail
  three consecutive checks before being considered unhealthy, but only
  two to be considered healthy. Biases toward admitting new tasks
  quickly (good for rolling deploys) while being patient about pulling
  existing ones out (avoids ejecting a task over one slow check).
- `interval = 30`, `timeout = 5`: standard defaults.
- `matcher = "200-399"`: covers redirects and other 2xx/3xx responses
  from a health endpoint. Services that issue 302 to canonicalize paths
  do not fail health checks for no reason.
- `deregistration_delay_seconds = 30`: low by default because most
  services here are stateless. Raise for any service that holds long-
  lived connections (SSE endpoints, websocket gateways).
- `health_check_grace_period_seconds = 60`: the ECS service waits this
  long after a task starts before subjecting it to ALB health checks.
  Covers normal cold-start latency.

### `lifecycle { ignore_changes = [desired_count] }`

If an Application Auto Scaling policy adjusts `desired_count` at
runtime, the next `terraform apply` must not reset it back to the
Terraform-declared value. This module does not own the autoscaling
policy (it belongs alongside whatever scaling signal is relevant — ALB
request count, SQS depth), so ignoring the attribute is the correct
decoupling.

### What this module does not do

- **Application Auto Scaling targets / policies.** Add them in a
  sibling module per service. The module exposes the service name and
  cluster so those resources can target it.
- **Service Connect / service discovery.** Out of scope.
- **Blue/green with CodeDeploy.** The circuit-breaker + deployment
  percents gives rolling deploys with automatic rollback; CodeDeploy
  blue/green adds a CodeDeploy app + deployment group + dedicated IAM
  role + hooks, which is overkill for this architecture.
