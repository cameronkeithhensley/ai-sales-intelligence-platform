# Module: ses

SES domain identity, DKIM signing, a MAIL FROM subdomain, and a v2
configuration set with CloudWatch event publishing. Transactional mail
only — customer-facing bulk outreach goes through a different channel
(see "Scope" below).

## Scope: transactional mail only

Per the architecture's split between transactional and bulk outreach:

- **SES handles transactional mail** — password resets, account
  verification emails, receipts, internal operator notifications,
  bounce summaries to admins. Volume is low, per-recipient is
  deterministic, deliverability requirements are high.
- **Bulk customer outreach goes through an external email delivery
  provider** — opted into per-tenant, with the provider's own
  reputation management, suppression lists, and ISP integration.
  SES's per-account reputation cannot absorb the volume or the
  deliverability complexity of tenant-initiated outreach. Using SES
  for that would risk the transactional sender score.

Keeping these separate means a reputation hit on the bulk channel
does not affect password-reset deliverability.

## What this module does

- **Domain identity** for the supplied `domain_name`.
- **DKIM** with three tokens exposed as outputs for DNS publication.
- **MAIL FROM subdomain** (default `bounce.<domain>`) with
  `behavior_on_mx_failure = "RejectMessage"` so a missing MX record
  causes SES to refuse the send rather than silently falling back to
  `amazonses.com`.
- **Configuration set** with reputation metrics on and a CloudWatch
  event destination capturing `SEND`, `DELIVERY`, `BOUNCE`,
  `COMPLAINT`, and `REJECT` events. The application must pass
  `ConfigurationSetName = <output>` on every send to get metrics and
  events.
- **TLS REQUIRE** as the default `delivery_options.tls_policy`.
  Recipients whose MX does not offer STARTTLS will not receive mail.
  Acceptable for transactional — if a recipient's provider cannot do
  TLS in 2026, there is no safe fallback.

## What this module does not do

- **Route 53 records.** DNS management lives in a separate admin
  account and is not the responsibility of this repo. DKIM tokens
  and the MAIL FROM MX target are exposed as outputs for the DNS
  admin to publish.
- **SES sandbox exit.** New SES accounts start in the sandbox (only
  verified recipients, 200/day). Moving to production access is an
  AWS-ticket request, not Terraform.
- **Dedicated IP pools.** Out of scope; transactional volume
  generally does not warrant dedicated IPs.
- **Bounce / complaint handlers.** EventBridge rules + Lambdas that
  parse the SES event destination belong in an ops module.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `domain_name` | SES identity domain (public placeholder in dev). |
| `mail_from_subdomain` | Defaults to `bounce`; prepended to `domain_name`. |
| `configuration_set_name` | Defaults to `<environment>-transactional`. |
| `tls_policy` | `REQUIRE` (default) or `OPTIONAL`. |
| `environment`, `tags` | Tagging. |

## Outputs (summary)

`domain_identity_arn`, `domain`, `dkim_tokens`, `mail_from_domain`,
`configuration_set_name`, `configuration_set_arn`.

## Design choices

### Why domain-based (DKIM) identity, not address-based

DKIM over a full domain lets the application send from any address
on that domain without a separate identity per address. It also lets
DMARC land a `pass` on both SPF and DKIM alignment, which is what
receiving mailbox providers actually evaluate. Verifying individual
email addresses as SES identities has none of those benefits and
requires a click on the verification link for every address.

### Why reputation metrics matter

SES shuts down senders whose bounce rate exceeds 5% or complaint
rate exceeds 0.1% — a sender in the "review" state cannot send until
the metrics recover. Without `reputation_metrics_enabled`, the first
signal is the shutdown. With them on, CloudWatch alarms can fire
well below the threshold and give the app a chance to suppress bad
addresses before SES makes the decision for it.

### Why `RejectMessage` on MX failure

If the MAIL FROM domain's MX record is missing or misconfigured, SES
can either fall back to `amazonses.com` (default) or reject the
message. Rejecting is the correct choice here: a silent fallback
breaks SPF alignment (SPF checks the MAIL FROM domain) and will
reduce the inbox placement rate. A visible rejection surfaces the
DNS error for operators to fix.
