# Module: ecs-cluster

A minimal ECS cluster primitive: a named cluster with Container Insights
on and both Fargate launch types wired up so services can opt into Spot
capacity per-task without any further cluster-level configuration.

## Why this shape

ECS has a long-standing footgun: you can create a cluster and a service,
but the service will fail to place tasks onto Fargate Spot unless the
cluster's `capacity_providers` list explicitly includes `FARGATE_SPOT`.
The error surface for that mistake is terrible (tasks just hang at
`PROVISIONING`). This module always associates both `FARGATE` and
`FARGATE_SPOT`, so the service side only has to decide its own weight.

The cluster itself carries no runtime state beyond the capacity-provider
association and the Container Insights setting. All the interesting
decisions — how much CPU, what log retention, which subnets, which IAM
policy — live on the services, in `ecs-service/`.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `name` | Cluster name, e.g. `dev-agents`. |
| `environment` | Tagging only. |
| `capacity_provider_default_weights` | Map of `FARGATE` / `FARGATE_SPOT` -> default weight. Providers with weight 0 stay associated (so services can opt in) but are not part of the default placement strategy. |
| `container_insights_enabled` | Defaults to `true`. |
| `tags` | Additional tag merge. |

## Outputs (summary)

`cluster_id`, `cluster_arn`, `cluster_name`.

## Design choices

### Fargate vs Fargate Spot

Fargate Spot is the same runtime as Fargate, billed at a ~70% discount,
with the catch that AWS can reclaim a task with two minutes of warning.
For the platform's workloads:

- **Dev and staging:** default to pure Fargate (weight `FARGATE = 1`,
  `FARGATE_SPOT = 0`). Reclaims during an interactive debugging session
  are an active nuisance, and the cost difference is negligible at dev
  scale.
- **Prod, for workers only:** shift to `FARGATE = 1`, `FARGATE_SPOT = 1`
  (or heavier Spot) on worker services (scout, harvester, profiler,
  writer). They pull jobs from SQS, so a reclaim simply means the
  in-flight job's visibility timeout expires and another worker picks it
  up. The existing DLQ + `max_receive_count` policies bound worst-case
  re-processing.
- **Prod, for load-balanced services:** keep on pure Fargate. A reclaim
  drops an in-flight HTTP response, which is visible to a user.

The module keeps both capacity providers associated so services can
override the cluster default per-service via their own
`capacity_provider_strategy` — there is no cluster-level change needed
to move a service between Fargate and Spot.

### Container Insights is on by default

Container Insights emits per-task CPU, memory, network, and storage
metrics to CloudWatch. It adds cost (per-metric ingestion) but it is the
only way to answer "why did this task OOM three hours ago" after the
fact — the task is gone, the CloudWatch logs have only application
output, and without Container Insights the resource metrics simply do
not exist. For a portfolio that is expected to spin up and down, leaving
Insights on trades a small running cost for one fewer class of
unanswerable incident question.

### What this module does not do

- **Service Connect / service mesh.** Adding Service Connect namespace
  defaults here would make the cluster opinionated about east-west
  routing. Defer to later if mesh is ever needed.
- **EC2 capacity.** This is a Fargate-only cluster. Adding EC2 capacity
  providers would entail ASGs, AMIs, lifecycle hooks, and drain logic —
  overkill for this architecture.
- **Execute command defaults.** `enable_execute_command` belongs on each
  service (it is useful for the worker services; usually off for
  dashboard-facing services).
