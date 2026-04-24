# Module: s3

An S3 bucket with the security and lifecycle defaults every bucket
should have from the start: public access blocked at every layer,
ownership mode that disables ACLs, server-side encryption on,
versioning on, a TLS-only bucket policy, and lifecycle rules that
keep noncurrent versions from growing unbounded. Intended for
artifact / export / tenant-asset storage, not static website hosting.

## Why this shape

The S3 primitive ships with footguns that security teams have spent
the better part of a decade auditing out of real environments:
public ACLs, object ownership split between uploader and bucket
owner, TLS not enforced. The default `aws_s3_bucket` resource gives
you none of those protections by default. This module fixes the
defaults once and makes opting out explicit.

## Per-tenant prefix isolation

In the larger platform, multi-tenant buckets use per-tenant
prefixes (`<bucket>/<tenant-id>/<...>`) enforced at the application
layer. Terraform does not try to create per-tenant IAM conditions —
that would turn every new tenant into an infrastructure apply.
Instead, the application's tenant context carries the prefix, and
the task role's bucket policy (attached separately) includes an
`aws:PrincipalTag/tenant_id` condition that pins prefix access to
the calling tenant.

This module provides the bucket layer; the policy layer that does
the per-tenant binding is attached by the service that owns the
bucket in question.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `bucket_name` | Globally-unique name. Include environment prefix. |
| `environment` | Tagging only. |
| `kms_key_arn` | Customer-managed KMS key for SSE-KMS. Null falls back to AES256. |
| `force_destroy` | Allow destroy of non-empty bucket. False in prod. |
| `versioning_enabled` | Default `true`. |
| `noncurrent_version_transition_days` / `noncurrent_version_expiration_days` / `incomplete_multipart_upload_days` | Lifecycle tuning. |
| `tags` | Additional tag merge. |

## Outputs (summary)

`bucket_arn`, `bucket_id`, `bucket_regional_domain_name`,
`bucket_domain_name`.

## Design choices

### Public access block: all four flags

`block_public_acls`, `ignore_public_acls`, `block_public_policy`,
and `restrict_public_buckets` are all set. Together they make the
bucket incapable of becoming public through any combination of
accidental ACL, accidental bucket policy, or legacy ACLs set by
uploaders. The four flags overlap on purpose: no single missed flag
creates an exposure.

### `BucketOwnerEnforced` ownership

Disables ACLs entirely. Every object is owned by the bucket owner,
and there is no ACL layer to misconfigure. This is strictly stronger
than `BucketOwnerPreferred` (which only applies to new objects
written by the bucket owner) and avoids the class of bug where a
cross-account uploader writes an object that the bucket owner then
cannot read.

If cross-account writes are ever required, they can be handled with
IAM permissions and `x-amz-acl: bucket-owner-full-control` is no
longer needed. Do not relax this to `ObjectWriter` without a
specific cross-account requirement.

### TLS-only policy

```
Effect: Deny
Principal: *
Action: s3:*
Condition: Bool { aws:SecureTransport = false }
```

Every S3 request that arrives without TLS is denied at the bucket
policy layer. The public-access block already prevents anonymous
access; this closes the hole where an authenticated client might
happen to hit an HTTP endpoint.

### Encryption

Defaults to `AES256` (SSE-S3). For data subject to audit / compliance
scopes, pass `kms_key_arn` to switch to `aws:kms` with a
customer-managed key and enable bucket keys (which cut KMS request
costs for high-throughput workloads). SSE-S3 is free; SSE-KMS costs
per-request, which matters at scale.

### Versioning + lifecycle

Versioning is on by default so that a client-side `DELETE` or
`PUT` overwrite leaves the previous object as a recoverable
noncurrent version. Without lifecycle rules, noncurrent versions
accumulate forever — the module transitions them to STANDARD_IA
after 30 days (cheaper storage tier for objects unlikely to be
restored) and expires them after 90 days.

Incomplete multipart uploads are aborted after 7 days by a separate
lifecycle rule. This single rule is worth its weight in gold:
failed big-file uploads stick around invisibly and are billed as
storage until cleaned up.

### What this module does not do

- **IAM policies for the bucket.** Per-service / per-tenant access
  is attached from the module that owns the consumer, not here.
  This module is bucket-shaped, not application-shaped.
- **Replication.** Cross-region replication is a compliance /
  disaster recovery decision that should be made per-bucket.
- **Object Lock / legal hold.** For regulated data use cases, the
  module would need to be amended to set Object Lock at bucket
  creation — it cannot be enabled after the fact.
- **Static website hosting.** Public hosting belongs behind
  CloudFront with an OAC, not on the bucket directly; that setup
  is a separate module.
