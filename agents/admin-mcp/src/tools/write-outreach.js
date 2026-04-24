// Tool: write_outreach
//
// Accepts a subject context + channel and requests an outbound
// message draft from the Writer pipeline. The prompt assembly, tone
// selection, and output post-processing are proprietary and live in
// the private repo. This stub records the intent and returns a
// placeholder payload — the public repo deliberately contains no
// prompt content.

const crypto = require("node:crypto");
const { z } = require("zod");

const InputSchema = z.object({
  subject_type: z.enum(["company", "property", "person"]),
  subject_id: z.string().uuid(),
  channel: z.enum(["email", "sms", "whatsapp"]),
});

module.exports = {
  name: "write_outreach",
  description:
    "Request an outbound message draft for the given subject on the chosen channel.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId } = await deps.tenants.resolveFromAuth(auth);

    const jobId = crypto.randomUUID();

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      jobId,
      agent: "writer",
      action: "tool.write_outreach",
      subjectType: input.subject_type,
      outcome: "allowed",
      metadata: { channel: input.channel, subject_id: input.subject_id },
    });

    // Prompt assembly is proprietary. No draft text is produced in
    // this build.
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            job_id: jobId,
            status: "stubbed",
            channel: input.channel,
          }),
        },
      ],
    };
  },
};
