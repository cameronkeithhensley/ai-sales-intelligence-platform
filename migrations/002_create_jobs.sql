-- Migration: 002_create_jobs
-- Purpose:   Create public.jobs (a.k.a. job_results) — async agent job
--            tracking. Producers write a row at enqueue time; workers
--            update status and result as they progress; callers poll
--            by (tenant_id, status) or by job_id.
-- Reference: docs/DATABASE.md, "public.jobs".
--
-- Idempotent. Assumes 001_create_tenants has been applied.

CREATE TABLE IF NOT EXISTS public.jobs (
    job_id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL
                                REFERENCES public.tenants(id)
                                ON DELETE CASCADE,
    agent           TEXT        NOT NULL,
    subject_type    TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'pending',
    result          JSONB,
    error_message   TEXT,
    policy_version  TEXT        NOT NULL,
    enqueued_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- Enum-style CHECK constraints

ALTER TABLE public.jobs
    DROP CONSTRAINT IF EXISTS jobs_agent_check;
ALTER TABLE public.jobs
    ADD  CONSTRAINT jobs_agent_check
    CHECK (agent IN (
        'scout',
        'harvester',
        'profiler',
        'writer',
        'holdsworth'
    ));

ALTER TABLE public.jobs
    DROP CONSTRAINT IF EXISTS jobs_status_check;
ALTER TABLE public.jobs
    ADD  CONSTRAINT jobs_status_check
    CHECK (status IN ('pending', 'running', 'completed', 'failed'));

-- Completed jobs must have completed_at; failed jobs must have an error.
-- Enforced at the row level so a worker cannot silently transition a job
-- into a terminal state with missing audit data.
ALTER TABLE public.jobs
    DROP CONSTRAINT IF EXISTS jobs_terminal_state_check;
ALTER TABLE public.jobs
    ADD  CONSTRAINT jobs_terminal_state_check
    CHECK (
        (status IN ('pending', 'running'))
        OR (status = 'completed' AND completed_at IS NOT NULL)
        OR (status = 'failed'    AND error_message IS NOT NULL)
    );

-- --- Indexes

-- Dominant read pattern: "jobs for this tenant", in recent-first order.
CREATE INDEX IF NOT EXISTS jobs_tenant_id_idx
    ON public.jobs (tenant_id);

-- Status dashboards / pending-work queries.
CREATE INDEX IF NOT EXISTS jobs_tenant_status_idx
    ON public.jobs (tenant_id, status);

-- For ops: "what is running / failing across all tenants right now?"
CREATE INDEX IF NOT EXISTS jobs_status_created_idx
    ON public.jobs (status, created_at DESC);

COMMENT ON TABLE  public.jobs                IS 'Async agent job tracking. Producers write at enqueue; workers update as they progress. See docs/DATABASE.md.';
COMMENT ON COLUMN public.jobs.policy_version IS 'Version of the policy rules in effect when the job ran. Used for audit replay — an older job can be re-evaluated against the policy that was current then.';
COMMENT ON COLUMN public.jobs.result         IS 'JSONB output payload. Schema varies by agent and subject_type.';
