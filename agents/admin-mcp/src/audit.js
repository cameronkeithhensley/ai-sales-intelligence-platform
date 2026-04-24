// Audit-log writer.
//
// Every policy-enforcement decision — including every MCP tool
// invocation — is appended to public.audit_log. DELETE is revoked on
// that table for tenant-scoped roles (see migrations/003), so a
// successful write here is a durable record.

/**
 * @typedef {object} AuditRecord
 * @property {string} tenantId
 * @property {string} [userId]
 * @property {string} [jobId]
 * @property {string} [agent]
 * @property {string} action
 * @property {string} [subjectType]
 * @property {string} [sourceLegalityTier]
 * @property {string} policyVersion
 * @property {"allowed"|"blocked"|"flagged"} outcome
 * @property {object} [metadata]
 */

/**
 * Build an audit writer bound to a pg Pool. Callers invoke
 * `audit.record(...)` on every tool invocation.
 *
 * @param {import('pg').Pool} pool
 * @param {object} [opts]
 * @param {string} [opts.defaultPolicyVersion]
 */
function buildAudit(pool, opts = {}) {
  const { defaultPolicyVersion = "0.0.0" } = opts;

  return {
    /**
     * @param {AuditRecord} record
     */
    async record(record) {
      const {
        tenantId,
        userId = null,
        jobId = null,
        agent = null,
        action,
        subjectType = null,
        sourceLegalityTier = null,
        policyVersion = defaultPolicyVersion,
        outcome,
        metadata = null,
      } = record;

      await pool.query(
        `INSERT INTO public.audit_log (
           tenant_id, user_id, job_id, agent, action,
           subject_type, source_legality_tier, policy_version,
           outcome, metadata
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          tenantId,
          userId,
          jobId,
          agent,
          action,
          subjectType,
          sourceLegalityTier,
          policyVersion,
          outcome,
          metadata === null ? null : JSON.stringify(metadata),
        ],
      );
    },
  };
}

module.exports = { buildAudit };
