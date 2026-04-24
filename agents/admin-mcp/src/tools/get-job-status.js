// Tool: get_job_status
//
// Reads a single job row from public.jobs, scoped to the caller's
// tenant. Does a real SELECT against the shared pool inside a
// withTenant scope, but returns a generic row shape.

const { z } = require("zod");
const { withTenant } = require("../../../shared/node/src/db");

const InputSchema = z.object({
  job_id: z.string().uuid(),
});

module.exports = {
  name: "get_job_status",
  description: "Fetch the status and result of a job by job_id.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId, schemaName } = await deps.tenants.resolveFromAuth(auth);

    const row = await withTenant(deps.pool, schemaName, async (client) => {
      const result = await client.query(
        `SELECT job_id, agent, status, enqueued_at, started_at, completed_at
           FROM public.jobs
          WHERE job_id = $1 AND tenant_id = $2
          LIMIT 1`,
        [input.job_id, tenantId],
      );
      return result.rows[0] ?? null;
    });

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      jobId: input.job_id,
      action: "tool.get_job_status",
      outcome: row ? "allowed" : "flagged",
      metadata: { found: Boolean(row) },
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(row ?? { job_id: input.job_id, status: "not_found" }),
        },
      ],
    };
  },
};
