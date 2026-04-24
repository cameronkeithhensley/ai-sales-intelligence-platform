# Module: vpc

A multi-AZ VPC primitive sized for a small-to-medium AWS workload. It provisions
the networking fabric every other module in this repo assumes exists: a VPC with
DNS support, symmetric public and private subnets across two or more AZs, an
internet gateway, NAT egress, route tables wired correctly on both sides, a set
of VPC endpoints that keep AWS-service traffic on the AWS backbone, and flow
logs for forensic visibility.

## Why

Most production failures in small AWS footprints trace back to skimping on one
of three things: network segmentation, AZ resilience, or audit trail. This
module bakes all three into one composable unit so that downstream modules
(RDS, ECS tasks, ALB, bastion) cannot accidentally skip them.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `cidr_block` | VPC CIDR. Default `10.0.0.0/16`. |
| `az_count` | Number of AZs to span (default 2). Must be `<= length(public_subnet_cidrs)`. |
| `public_subnet_cidrs` | One CIDR per AZ. |
| `private_subnet_cidrs` | One CIDR per AZ. |
| `multi_nat_enabled` | `false` → one shared NAT (cheap). `true` → one NAT per AZ (resilient). |
| `enable_flow_logs` | When `true`, emit ALL-traffic flow logs to CloudWatch. |
| `flow_logs_retention_days` | Log retention for the flow logs log group. |
| `environment` / `tags` | Tagging. |

## Outputs (summary)

`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ids`,
`private_route_table_ids`, `vpc_endpoint_ids` (map), `flow_logs_log_group_name`,
plus the security group ID for the interface endpoints.

## Design choices

### Single-NAT vs multi-NAT (`multi_nat_enabled`)

A NAT gateway is billed at roughly `$0.045/hr` per AZ, plus data-processing
charges. For a two-AZ VPC, that is ~$32/month for one NAT versus ~$64/month for
AZ-redundant NAT — before traffic. On a demo or pre-production environment the
single-NAT default is the right call: if the NAT's AZ goes down, the VPC loses
outbound internet for private subnets, but no customer traffic is at stake.
For production environments or anything with a real SLO, flip `multi_nat_enabled
= true` so that losing one AZ does not take the whole workload offline. The
module wires the private route tables accordingly: one table shared across all
private subnets in single-NAT mode, or one table per AZ each routing to its
local NAT in multi-NAT mode.

### VPC endpoints

NAT is where the dollars hide. Every ECR image pull, every Secrets Manager
lookup from a running task, every SQS long-poll — left to its own devices, all
of that traffic leaves the VPC through the NAT gateway and is billed at data
processing rates. Worse, it transits the public internet even though both
endpoints are AWS-owned. Two changes eliminate that:

1. **S3 gateway endpoint.** Free. Terraform attaches it to every private route
   table so that S3 calls from private subnets resolve over the endpoint
   automatically. ECR pulls are an ECR-over-S3 operation for the image layers,
   so this shaves a substantial chunk of pull egress.
2. **Interface endpoints for `ecr.api`, `ecr.dkr`, `secretsmanager`, `sqs`.**
   These cost ~$0.01/hr per AZ per endpoint but eliminate per-GB NAT traversal
   for these services entirely. They also keep the traffic on the AWS backbone,
   which is a control-plane story for security review: a leaked credential in a
   private subnet cannot call these services via the public internet even if it
   wanted to.

Downstream modules do not need to know the endpoints exist — AWS SDK clients
pick them up via private DNS.

### Flow logs

Enabled by default. Sent to a dedicated CloudWatch log group with 30-day
retention (tunable). The IAM role is scoped to publishing only to that one log
group. Flow logs are noisy but invaluable on the day you need to answer
"when did this host first talk to that CIDR?" — and the ~$0.50/GB ingest cost
is rounding-error versus the cost of not having them during an incident.

### What this module does not do

- **Transit Gateway / VPC peering** — not needed for a single-account demo.
- **IPv6** — out of scope; this repo is IPv4-only.
- **VPN / DX** — not needed; bastion + SSM is the ops path (see `bastion/`).
