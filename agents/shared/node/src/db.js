// Postgres pool + per-tenant search_path routing.
//
// Every per-tenant query runs inside withTenant(pool, schemaName, fn). The
// helper acquires a pooled client, pins its search_path to the tenant's
// schema, hands it to the callback, and resets on release. A caller that
// bypasses withTenant is bypassing tenant isolation — lint this at review
// time if it ever drifts.

const { Pool } = require("pg");

const IDENT_RE = /^[a-z][a-z0-9_]{0,62}$/;

/**
 * Validate and quote a Postgres identifier. Throws when the input does not
 * match [a-z][a-z0-9_]* — tenant schema names come from the application's
 * tenants table, but a defensive check here keeps a compromised row or a
 * typo from turning into SQL injection through string interpolation.
 *
 * @param {string} ident
 * @returns {string} Double-quoted identifier safe for interpolation.
 */
function quoteIdent(ident) {
  if (typeof ident !== "string" || !IDENT_RE.test(ident)) {
    throw new Error(
      `Invalid SQL identifier: ${JSON.stringify(ident)}. ` +
        "Must match /^[a-z][a-z0-9_]{0,62}$/.",
    );
  }
  return `"${ident}"`;
}

/**
 * Build a Pool from a connection URL. Pool defaults are conservative for
 * Fargate — the task count is typically low, and RDS max_connections is
 * not infinite.
 *
 * @param {string} connectionString
 * @param {import('pg').PoolConfig} [extra]
 * @returns {Pool}
 */
function makePool(connectionString, extra = {}) {
  return new Pool({
    connectionString,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    ...extra,
  });
}

/**
 * Run a callback with a pooled client whose search_path is pinned to the
 * tenant's schema. The schema name is validated as an identifier before
 * being interpolated; interpolation is unavoidable because SET search_path
 * does not accept bound parameters.
 *
 * @template T
 * @param {Pool} pool
 * @param {string} tenantSchemaName
 * @param {(client: import('pg').PoolClient) => Promise<T>} fn
 * @returns {Promise<T>}
 */
async function withTenant(pool, tenantSchemaName, fn) {
  const quoted = quoteIdent(tenantSchemaName);
  const client = await pool.connect();
  try {
    await client.query(`SET search_path TO ${quoted}, public`);
    return await fn(client);
  } finally {
    try {
      await client.query("RESET search_path");
    } catch {
      // If RESET itself fails the client is probably unusable; release it
      // and let the pool reap a fresh one.
    }
    client.release();
  }
}

module.exports = { makePool, withTenant, quoteIdent };
