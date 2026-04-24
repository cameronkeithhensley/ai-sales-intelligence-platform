# Module: alb

A public-facing Application Load Balancer sized to be the single ingress
point for every HTTPS service in the platform. This module provisions the
ALB, its security group, the HTTP-to-HTTPS redirect listener, and an HTTPS
listener whose default action is a 404 fixed-response. Target groups and
host-based routing rules are added in Sprint 2, outside this module.

## Why one ALB, host-based routing

The platform ships three public services: the tenant-facing dashboard
(Next.js), the butler (tenant MCP endpoint), and the admin MCP server.
Each gets its own hostname, not its own load balancer:

- **Cost.** A second ALB is ~$18/month minimum. Three of them is real money.
- **Certificate management.** ACM certs are per-ALB; one ALB means one
  certificate request / renewal path.
- **WAF attachment.** One `aws_wafv2_web_acl_association` in Sprint 2
  covers every service behind the ALB.
- **Security posture.** Rate limits, header policies, and access log
  format are consistent across all services because they share the
  physical edge.

Host-based routing is done with `aws_lb_listener_rule` resources
(added in Sprint 2), each matching on `Host` header and forwarding to the
target group for that service.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `vpc_id` / `public_subnet_ids` | Where the ALB sits; subnets must span ≥ 2 AZs. |
| `certificate_arn` | Primary ACM cert for the HTTPS listener. |
| `additional_certificate_arns` | SNI certs for additional hostnames. |
| `ssl_policy` | Default `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2+ only). |
| `access_logs_bucket` / `access_logs_prefix` | Optional S3 access log target. Null disables. |
| `idle_timeout` | Default 60s. Raise for SSE / long-poll endpoints. |
| `enable_deletion_protection` | True for prod. |
| `drop_invalid_header_fields` | True — drop bad headers at the edge. |

## Outputs (summary)

`alb_arn`, `alb_dns_name`, `alb_zone_id`, `https_listener_arn`,
`http_listener_arn`, `security_group_id`.

## Design choices

### HTTP listener is a pure redirect

Port 80's only job is to return `301 Location: https://...` so that
browsers trying the bare `http://dashboard.example.com` get upgraded.
There is no hole to forget — the default action is the redirect, and
nothing else attaches to port 80.

### HTTPS listener default action is `404`

An ALB that forwards *anything* hitting port 443 to *some* backend leaks
the existence of a service to any scanner probing on port 443. Returning
`404: unknown host` as the default means only hosts explicitly wired up by
`aws_lb_listener_rule` reach a backend; everything else gets a stock 404.

### Where ACM certificates live

Real ACM certificates are **not** checked into this repo. They cannot live
in a demo repo: the certificate ARN depends on the AWS account + region
the cert was issued in, and the portfolio repo uses the placeholder
account `000000000000`. For a real deployment, the cert lives in ACM in
the same region as the ALB and its ARN is passed as a variable at apply
time.

### WAF attachment is Sprint 2

`aws_wafv2_web_acl_association` attaches a WAF web ACL to the ALB. That
belongs in the WAF module (Sprint 2) rather than here so the ACL rules
themselves can live with the WAF resources and the ACL can be attached /
detached without touching the ALB definition.

### `drop_invalid_header_fields = true`

Requests with invalid header fields (non-printable characters, CRLF
injection attempts, malformed headers) are dropped at the ALB rather than
forwarded to the backend. This is defense-in-depth against header-smuggling
bugs that target the origin's parser.
