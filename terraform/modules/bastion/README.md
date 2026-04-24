# Module: bastion

A small EC2 instance in a private subnet whose only purpose is to give
operators a shell inside the VPC — without SSH, without public IPs, without
key pairs to rotate, and without inbound security group rules. Access is
exclusively via AWS Systems Manager Session Manager.

## Why SSM Session Manager instead of SSH

SSH bastions are a known-bad pattern at this point. They require a public
IP or port-forwarding hoop, a key-pair rotation discipline that nobody
actually follows, and an inbound-allowlist that drifts out of date. SSM
Session Manager solves all three:

- **No inbound security group rules.** The SSM Agent on the instance dials
  out to the SSM endpoints over 443. The bastion SG in this module has zero
  ingress rules.
- **No SSH keys.** Authentication is IAM. Who can start a session is
  governed by IAM policies attached to the operator's principal, not by who
  holds a `.pem` file.
- **Full CloudTrail audit trail.** `StartSession` and `TerminateSession`
  events are logged. With session logging enabled (a CloudWatch or S3 target
  on the SSM document), the keystrokes are captured too.
- **Works across VPC + account boundaries.** Future multi-account setups can
  route admin access through a central SSM endpoint rather than peering
  VPCs or publishing public IPs.

The bastion is not a persistent workhorse — it exists so an operator can
`psql` into RDS to run migrations or poke at tenant data during an incident.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `vpc_id` | VPC the bastion SG belongs to. |
| `subnet_id` | **Private** subnet to place the instance in. |
| `instance_type` | `t3.micro` default; this is not a workhorse. |
| `additional_security_group_ids` | Extra SGs to attach (rarely needed). |
| `root_volume_size` / `kms_key_id` | Encrypted gp3 root, default AWS-managed key. |
| `additional_iam_policy_arns` | Extra policies beyond `AmazonSSMManagedInstanceCore`. |
| `user_data_extra` | Extra shell appended to the default cloud-init. |

## Outputs (summary)

`instance_id` (use this with `aws ssm start-session`), `security_group_id`
(add to the RDS module's `allowed_security_group_ids`), `iam_role_arn`,
`iam_role_name`, `iam_instance_profile_name`.

## Design choices

### AMI lookup

The latest Amazon Linux 2023 AMI is looked up at plan time via
`data "aws_ami"`. `ami` and `user_data` are in `ignore_changes` so that an
Amazon AMI roll does not cause Terraform to replace the instance on every
apply — operators opt into a refresh by tainting the instance.

### User data installs `postgresql15`

Cloud-init installs the Postgres client so that `psql`, `pg_dump`, and
`pg_restore` are available for migrations against the RDS instance.
Migrations themselves are not baked into the bastion image — they come in
from the application repo and are executed against `psql` from here.

### IMDSv2 is required

`http_tokens = "required"` disables IMDSv1. This closes the server-side
request forgery path that has caused multiple high-profile cloud breaches.
The hop limit is set to 2 so that container runtimes on the instance can
still reach the metadata service if needed.

### Encrypted root volume

`gp3`, encrypted, and tagged. Decryption uses the AWS-managed EBS key by
default; pass `kms_key_id` to use a customer-managed key.

### How to use

From an operator workstation with the right IAM permissions:

```bash
aws ssm start-session --target <instance_id>
# then inside the session:
PGPASSWORD=... psql -h <rds_endpoint> -U app_admin -d app_db
```

With the Session Manager plugin installed, port forwarding works the same way:

```bash
aws ssm start-session \
  --target <instance_id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="<rds_endpoint>",portNumber="5432",localPortNumber="5432"
```

### What this module does not do

- **Session logging configuration.** That lives on the SSM document, not the
  instance. Configure a per-account logging target for `SSM-SessionManagerRunShell`.
- **Scheduled stop/start.** If you want the bastion off outside work hours,
  wire up an EventBridge rule separately.
