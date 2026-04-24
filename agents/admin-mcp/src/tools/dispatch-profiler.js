// Tool: dispatch_profiler
//
// Enqueues a Profiler (passive-recon) job. Profiler runs DNS-only
// passive reconnaissance; no active scanning.

const crypto = require("node:crypto");
const { z } = require("zod");

const InputSchema = z.object({
  subject_type: z.enum(["company", "property", "person"]),
  subject_id: z.string().uuid(),
});

module.exports = {
  name: "dispatch_profiler",
  description: "Enqueue a Profiler job for the given subject.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId } = await deps.tenants.resolveFromAuth(auth);

    const jobId = crypto.randomUUID();

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      jobId,
      agent: "profiler",
      action: "tool.dispatch_profiler",
      subjectType: input.subject_type,
      outcome: "allowed",
      metadata: { subject_id: input.subject_id },
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ job_id: jobId, status: "stubbed" }),
        },
      ],
    };
  },
};
