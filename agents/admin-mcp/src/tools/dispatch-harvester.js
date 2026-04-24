// Tool: dispatch_harvester
//
// Enqueues a Harvester job. The set of adapters Harvester actually
// consults against a given subject is governed by policy that lives
// in the private repo; this stub accepts the request and returns a
// job id.

const crypto = require("node:crypto");
const { z } = require("zod");

const InputSchema = z.object({
  subject_type: z.enum(["company", "property", "person"]),
  subject_id: z.string().uuid(),
});

module.exports = {
  name: "dispatch_harvester",
  description: "Enqueue a Harvester job for the given subject.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId } = await deps.tenants.resolveFromAuth(auth);

    const jobId = crypto.randomUUID();

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      jobId,
      agent: "harvester",
      action: "tool.dispatch_harvester",
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
