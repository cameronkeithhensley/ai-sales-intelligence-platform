-- Migration: 004_create_outreach_events
-- Purpose:   Create public.outreach_events — log of every outbound
--            customer-facing message attempt. Serves as the
--            CAN-SPAM / telecom-compliance audit trail.
-- Reference: docs/DATABASE.md, "public.outreach_events".
--
-- Idempotent. Assumes 001_create_tenants has been applied.

CREATE TABLE IF NOT EXISTS public.outreach_events (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            UUID        NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    contact_type         TEXT        NOT NULL,
    contact_value        TEXT        NOT NULL,
    event_type           TEXT        NOT NULL,
    provider_message_id  TEXT,
    subject_line         TEXT,
    metadata             JSONB,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- Closed-set CHECK constraints on the type / event enums.

ALTER TABLE public.outreach_events
    DROP CONSTRAINT IF EXISTS outreach_events_contact_type_check;
ALTER TABLE public.outreach_events
    ADD  CONSTRAINT outreach_events_contact_type_check
    CHECK (contact_type IN ('email', 'sms', 'whatsapp'));

ALTER TABLE public.outreach_events
    DROP CONSTRAINT IF EXISTS outreach_events_event_type_check;
ALTER TABLE public.outreach_events
    ADD  CONSTRAINT outreach_events_event_type_check
    CHECK (event_type IN (
        'sent',
        'blocked',
        'bounce_hard',
        'bounce_soft',
        'complaint',
        'delivered',
        'open',
        'click'
    ));

-- --- Indexes: per-tenant time-series reads (the compliance dashboard
--              read pattern), per-contact history (for opt-out /
--              suppression list checks), and provider message id
--              reverse-lookup (for webhook processing that arrives
--              with the provider id and needs to find the originating
--              row).

CREATE INDEX IF NOT EXISTS outreach_events_tenant_created_idx
    ON public.outreach_events (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS outreach_events_contact_value_idx
    ON public.outreach_events (contact_value);

CREATE INDEX IF NOT EXISTS outreach_events_provider_message_id_idx
    ON public.outreach_events (provider_message_id)
    WHERE provider_message_id IS NOT NULL;

COMMENT ON TABLE  public.outreach_events IS 'Log of every outbound customer-facing message attempt — CAN-SPAM / telecom-compliance audit trail.';
COMMENT ON COLUMN public.outreach_events.contact_value       IS 'Destination address or number, as sent. Used in suppression list lookups — do not hash or redact here.';
COMMENT ON COLUMN public.outreach_events.provider_message_id IS 'Upstream message id from the delivery provider, when returned. Enables correlating provider webhooks back to the originating row.';
