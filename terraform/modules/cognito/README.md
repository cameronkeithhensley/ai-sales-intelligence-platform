# Module: cognito

A Cognito user pool plus a confidential OAuth 2.0 / OIDC client for the
tenant dashboard. The pool is set up for the authorization-code-with-PKCE
flow with the client secret held server-side; the dashboard's server-side
rendering layer is the only thing that handles tokens.

## Why Cognito (vs. rolling auth)

Three jobs I do not want to reinvent: hashing passwords with an
evidence-backed scheme, mailing password-reset links that expire, and
serving a standards-compliant OIDC discovery document. Cognito handles all
three. The rest of auth — role assignment, tenant membership, session
lifecycle — lives in the app on top of Cognito's ID token.

## Why confidential client + PKCE

The tenant dashboard is a Next.js app whose routes render server-side. The
server holds the Cognito client secret; browsers never see it. PKCE is
belt-and-suspenders against the handful of attacks on the redirect leg
that exchange authorization codes back for tokens (code interception in
a rogue extension, for instance). Specifically:

- `generate_secret = true` makes this a confidential client; the secret is
  stored in Secrets Manager at deploy time and read by the server.
- `allowed_oauth_flows = ["code"]` permits only the authorization code
  flow. No implicit, no password grant, no client credentials.
- `explicit_auth_flows` enables SRP (secure remote password) and refresh
  only; legacy `USER_PASSWORD_AUTH` is disabled.
- `prevent_user_existence_errors = "ENABLED"` avoids leaking whether a
  particular email address is registered in the pool.
- `allowed_oauth_scopes = ["openid", "profile", "email"]` — the minimum
  needed for an OIDC sign-in. Custom scopes are added per-resource-server
  later, outside this module.

## Tenant resolution

The platform uses Cognito's `sub` (a stable, opaque user identifier) as
the authoritative identity key. At request time the app looks up the
`sub` in the `tenants` table to find the tenant's schema name. See
[`ARCHITECTURE.md` §5](../../../ARCHITECTURE.md) for the full mapping.

The user pool schema includes a `tenant_id` custom attribute as an
optional cache slot — if the app chooses to avoid the extra DB lookup on
the hot path, it can put the tenant id there. The attribute is
`mutable = true` so onboarding and re-assignment work cleanly.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `user_pool_name` / `domain_prefix` | Pool name and hosted-UI subdomain prefix. The prefix must be globally unique in the region. |
| `callback_urls` / `logout_urls` | OAuth redirect allowlists. |
| `mfa_configuration` | `OFF`, `OPTIONAL` (default), or `ON`. |
| `access_token_validity_minutes`, `id_token_validity_minutes`, `refresh_token_validity_days` | Token lifetimes. |
| `deletion_protection` | `ACTIVE` for prod. |

## Outputs (summary)

`user_pool_id`, `user_pool_arn`, `user_pool_endpoint`,
`user_pool_client_id`, `user_pool_client_secret` (sensitive),
`user_pool_domain`.

## Design choices

### Password policy

12 character minimum with upper/lower/digit/symbol required.
Temporary passwords (admin-created) expire in 3 days. The specifics are
modern-NIST-aligned (length dominates complexity), not a compliance
checklist.

### MFA: TOTP only; SMS off

When MFA is enabled (`OPTIONAL` or `ON`), only `software_token_mfa`
(TOTP authenticators like Authy/1Password/Google Authenticator) is
enabled. SMS MFA is deliberately not configured because it (a) requires
an SNS role on the pool, (b) has a known toll-fraud vector where
attackers enroll premium-rate numbers to drain an SNS budget, and (c) is
no longer considered strong authentication. If a customer needs SMS for
UX reasons, configure it explicitly at apply time.

### Account recovery: email only

Same reasoning — no SMS recovery path.

### Advanced security: `AUDIT` mode

`advanced_security_mode = "AUDIT"` turns on Cognito's risk-based
analytics without yet *blocking* risky sign-ins. This puts the signals in
CloudWatch (unusual IPs, credential stuffing patterns) so an operator can
tune thresholds before flipping to `ENFORCED` in prod.

### Email sender

`email_sending_account = "COGNITO_DEFAULT"` uses the Cognito-operated
sender with its per-day limit. For production, swap in an SES
configuration set ARN so bounces and complaints go into the same
observability pipeline as transactional mail.

### Token lifetimes

Defaults: 60-minute access / ID tokens, 30-day refresh tokens. The access
token lifetime is short enough that a leaked token has a small blast
radius; the refresh token is long enough that users do not get bounced
out of the dashboard during a normal workday. Both are variable so the
defaults can be tightened per environment.
