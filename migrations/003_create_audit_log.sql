-- Migration: 003_create_audit_log
-- Purpose:   Create public.audit_log — append-only cross-tenant record
--            of every policy-enforcement decision. Tenant-scoped
--            database roles cannot DELETE from this table; operators
--            doing forensics use a privileged role.
-- Reference: docs/DATABASE.md, "public.audit_log".
--
-- Idempotent. Assumes 001_create_tenants has been applied.

CREATE TABLE IF NOT EXISTS public.audit_log (
    id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id              UUID        REFERENCES public.tenants(id) ON DELETE SET NULL,
    user_id                UUID,
    job_id                 UUID,
    agent                  TEXT,
    action                 TEXT        NOT NULL,
    subject_type           TEXT,
    source_legality_tier   TEXT,
    policy_version         TEXT        NOT NULL,
    outcome                TEXT        NOT NULL,
    metadata               JSONB,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- Outcome is a closed set.

ALTER TABLE public.audit_log
    DROP CONSTRAINT IF EXISTS audit_log_outcome_check;
ALTER TABLE public.audit_log
    ADD  CONSTRAINT audit_log_outcome_check
    CHECK (outcome IN ('allowed', 'blocked', 'flagged'));

-- --- Indexes: dominant read patterns are "audit trail for this tenant,
--              recent first" and "all events for this job".

CREATE INDEX IF NOT EXISTS audit_log_tenant_created_idx
    ON public.audit_log (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS audit_log_job_id_idx
    ON public.audit_log (job_id)
    WHERE job_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS audit_log_outcome_created_idx
    ON public.audit_log (outcome, created_at DESC);

-- --- Append-only enforcement at the database layer.
--
-- Revoking DELETE from PUBLIC means that a tenant-scoped role — created
-- later, inheriting no explicit grants on public.audit_log beyond
-- INSERT/SELECT — will not be able to erase its own audit trail.
-- Forensic queries use a privileged role that does hold DELETE; that
-- role lives outside the tenant permission boundary.

REVOKE DELETE ON public.audit_log FROM PUBLIC;

COMMENT ON TABLE  public.audit_log IS 'Append-only policy audit trail. DELETE is revoked from tenant-scoped roles; forensic deletes go through a privileged role.';
COMMENT ON COLUMN public.audit_log.outcome              IS 'allowed | blocked | flagged. Flagged means the decision was allowed but warrants review.';
COMMENT ON COLUMN public.audit_log.source_legality_tier IS 'Legality classification of the data source consulted during the decision, if any. Populated from the policy evaluation output.';
