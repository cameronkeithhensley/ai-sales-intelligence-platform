-- Migration: 001_create_tenants
-- Purpose:   Create the public.tenants registry. Maps an authenticated
--            Cognito identity to a tenant UUID and the name of that
--            tenant's dedicated PostgreSQL schema.
-- Reference: docs/DATABASE.md, "public.tenants".
--
-- Idempotent. Safe to re-run. Designed to be executed from the bastion
-- via psql; see terraform/modules/bastion/README.md for the operator
-- workflow.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- --- Enum-style text columns backed by CHECK constraints.
--
-- Using CHECK rather than native ENUM types is deliberate: adding a new
-- value to a CHECK constraint is a one-statement ALTER; adding a new
-- ENUM value is a painful cross-backend dance. These values are also
-- read by application code, and text is trivially portable.

CREATE TABLE IF NOT EXISTS public.tenants (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT        NOT NULL,
    tier         TEXT        NOT NULL,
    tenant_type  TEXT        NOT NULL,
    cognito_sub  TEXT        NOT NULL,
    schema_name  TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tenant tiers drive quota enforcement at the service layer. Keep the
-- catalog here narrow; application-level tiers can extend it.
ALTER TABLE public.tenants
    DROP CONSTRAINT IF EXISTS tenants_tier_check;
ALTER TABLE public.tenants
    ADD  CONSTRAINT tenants_tier_check
    CHECK (tier IN ('free', 'starter', 'growth', 'enterprise'));

-- Tenant category gates which agents and data sources apply to a
-- tenant. Values intentionally high-level here — per-tenant specifics
-- live in the tenant's own schema.
ALTER TABLE public.tenants
    DROP CONSTRAINT IF EXISTS tenants_tenant_type_check;
ALTER TABLE public.tenants
    ADD  CONSTRAINT tenants_tenant_type_check
    CHECK (tenant_type IN ('standard', 'restricted', 'internal'));

-- --- Indexes

CREATE UNIQUE INDEX IF NOT EXISTS tenants_cognito_sub_key
    ON public.tenants (cognito_sub);

CREATE UNIQUE INDEX IF NOT EXISTS tenants_schema_name_key
    ON public.tenants (schema_name);

-- --- updated_at trigger

CREATE OR REPLACE FUNCTION public.tenants_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tenants_set_updated_at ON public.tenants;
CREATE TRIGGER tenants_set_updated_at
    BEFORE UPDATE ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.tenants_set_updated_at();

COMMENT ON TABLE  public.tenants             IS 'Master tenant registry. Maps Cognito sub -> tenant UUID -> per-tenant schema name. See docs/DATABASE.md.';
COMMENT ON COLUMN public.tenants.cognito_sub IS 'OIDC subject from Cognito. Stable per-user across sessions; unique per tenant.';
COMMENT ON COLUMN public.tenants.schema_name IS 'Name of this tenants dedicated PostgreSQL schema. The tenants database role has search_path scoped to this schema + selected public tables.';
