# dashboard

Portfolio skeleton for the tenant-facing dashboard. Next.js 14 app
router, NextAuth wired to the Cognito user pool provisioned by the
Sprint 1 `cognito` Terraform module, and a minimal landing page.

The production tenant UX — signals, leads, tenant-scoped settings,
policy controls, operator surfaces — is proprietary and does not ship
in this public repository. This skeleton exists so reviewers can see
the Next.js 14 + NextAuth Cognito wiring that the real UI is built on.

## Runtime

- `src/index.js` is the Docker entry point (`node src/index.js`). It
  boots Next.js programmatically, intercepts `GET /healthz` for the
  ALB target-group health check, and delegates everything else to
  Next. This keeps the Sprint 2 Dockerfile interface (one Node entry,
  port 8080, `/healthz` plain-text `ok`) intact.
- `app/api/auth/[...nextauth]/route.ts` mounts NextAuth with the
  Cognito provider. Required env:
  `COGNITO_ISSUER=https://cognito-idp.<region>.amazonaws.com/<user_pool_id>`,
  `COGNITO_CLIENT_ID=<app_client_id>`,
  `COGNITO_CLIENT_SECRET=<app_client_secret>` (required for the
  confidential client the Terraform module provisions),
  `NEXTAUTH_URL=https://dashboard.<domain>`,
  `NEXTAUTH_SECRET=<random>`.
- `app/api/health/route.ts` provides a JSON `/api/health` endpoint in
  addition to the plain-text `/healthz` that the custom server
  handles.
