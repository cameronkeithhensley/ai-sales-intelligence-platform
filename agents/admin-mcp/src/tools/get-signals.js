// Tool: get_signals
//
// Returns recent signal rows for the caller's tenant. The real
// signal schema (tables, strength weights, type catalog) is
// proprietary and does not live in the public repo; this handler
// reads from public.jobs as a portable stand-in so reviewers can
// see the tenant-scoped query shape.

const { z } = require("zod");
const { withTenant } = require("../../../shared/node/src/db");

const InputSchema = z.object({
  subject_type: z.enum(["company", "property", "person"]).optional(),
  limit: z.number().int().min(1).max(100).default(20),
});

module.exports = {
  name: "get_signals",
  description: "Fetch recent signals for the caller's tenant.",
  inputSchema: InputSchema,

  async handler({ auth, input, deps }) {
    const { tenantId, schemaName } = await deps.tenants.resolveFromAuth(auth);

    const rows = await withTenant(deps.pool, schemaName, async (client) => {
      const params = [tenantId, input.limit];
      let where = "tenant_id = $1";
      if (input.subject_type) {
        params.push(input.subject_type);
        where += ` AND subject_type = $${params.length}`;
      }
      const result = await client.query(
        `SELECT job_id, agent, subject_type, status, enqueued_at, completed_at
           FROM public.jobs
          WHERE ${where}
          ORDER BY enqueued_at DESC
          LIMIT $2`,
        params,
      );
      return result.rows;
    });

    await deps.audit.record({
      tenantId,
      userId: auth.sub,
      action: "tool.get_signals",
      outcome: "allowed",
      metadata: { count: rows.length, subject_type: input.subject_type ?? null },
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ signals: rows }),
        },
      ],
    };
  },
};
