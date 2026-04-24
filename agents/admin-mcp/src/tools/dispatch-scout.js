// Tool: dispatch_scout
//
// Enqueues a Scout job for a subject. Production orchestration —
// priority queues, tenant quota, deduplication — is proprietary and
// lives in the private repo. This stub records the audit trail and
// returns a well-formed MCP response so reviewers can see the tool
// shape.

const crypto = require("node:crypto");
const { z } = require("zod");

const InputSchema = z.object({
  subject_type: z.enum(["company", "property", "person"]),
  subject_id: z.string().uuid(),
});

module.exports = {
  name: "dispatch_scout",
  description: "Enqueue a Scout job for the given subject.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId } = await deps.tenants.resolveFromAuth(auth);

    const jobId = crypto.randomUUID();

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      jobId,
      agent: "scout",
      action: "tool.dispatch_scout",
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
