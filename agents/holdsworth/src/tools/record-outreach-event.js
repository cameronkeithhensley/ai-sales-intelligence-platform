// Tool: record_outreach_event
//
// Inserts a single row into public.outreach_events. Used by the agent
// loop after the SMS / email delivery provider acknowledges a send
// (and by the webhook handler on subsequent lifecycle events — bounce,
// complaint, delivered, open, click).

const { z } = require("zod");

const InputSchema = z.object({
  tenant_id: z.string().uuid(),
  contact_type: z.enum(["email", "sms", "whatsapp"]),
  contact_value: z.string().min(1),
  event_type: z.enum([
    "sent",
    "blocked",
    "bounce_hard",
    "bounce_soft",
    "complaint",
    "delivered",
    "open",
    "click",
  ]),
  provider_message_id: z.string().optional(),
  subject_line: z.string().optional(),
  metadata: z.record(z.any()).optional(),
});

module.exports = {
  name: "record_outreach_event",
  inputSchema: InputSchema,

  async handler({ input, deps }) {
    const parsed = InputSchema.parse(input);
    await deps.pool.query(
      `INSERT INTO public.outreach_events (
         tenant_id, contact_type, contact_value, event_type,
         provider_message_id, subject_line, metadata
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        parsed.tenant_id,
        parsed.contact_type,
        parsed.contact_value,
        parsed.event_type,
        parsed.provider_message_id ?? null,
        parsed.subject_line ?? null,
        parsed.metadata ? JSON.stringify(parsed.metadata) : null,
      ],
    );
    return { status: "recorded" };
  },
};
