// Admin MCP server entry point.
//
// Boots an Express app exposing the MCP tool surface over HTTP, with
// JWT-guarded tool endpoints. GET /healthz is unauthenticated on 8080
// so the Sprint 2 Dockerfile HEALTHCHECK keeps working unchanged.

const { z } = require("zod");

const {
  BaseConfigSchema,
  loadConfig,
  buildLogger,
  makePool,
  buildVerifier,
  requireJwt,
} = require("../../shared/node/src");
const { buildApp } = require("./server");
const { buildAudit } = require("./audit");

const ConfigSchema = BaseConfigSchema.extend({
  PORT: z.coerce.number().int().positive().default(8080),
  POLICY_VERSION: z.string().default("0.0.0"),
});

async function main() {
  const cfg = loadConfig(ConfigSchema);
  const logger = buildLogger({ level: cfg.LOG_LEVEL, service: "admin-mcp" });
  const pool = makePool(cfg.DATABASE_URL);

  // In dev without Cognito wired, skip the middleware so operators can
  // poke the surface with curl. Production always has the pool ids set.
  let jwtMiddleware;
  if (cfg.COGNITO_USER_POOL_ID && cfg.COGNITO_USER_POOL_CLIENT_ID) {
    const verifier = buildVerifier({
      userPoolId: cfg.COGNITO_USER_POOL_ID,
      clientId: cfg.COGNITO_USER_POOL_CLIENT_ID,
    });
    jwtMiddleware = requireJwt(verifier);
  } else {
    logger.warn({ msg: "admin-mcp.jwt.disabled" });
  }

  const deps = {
    logger,
    pool,
    audit: buildAudit(pool, { defaultPolicyVersion: cfg.POLICY_VERSION }),
    tenants: {
      // Tenant resolution implementation lives in the private repo
      // alongside the full tenants-table row model. The public build
      // returns a deterministic stub keyed on the JWT sub so downstream
      // code paths run end-to-end without a real DB.
      async resolveFromAuth(auth) {
        return {
          tenantId: auth?.sub ?? "00000000-0000-0000-0000-000000000000",
          schemaName: "public",
        };
      },
    },
  };

  const app = buildApp({ deps, jwtMiddleware });

  const server = app.listen(cfg.PORT, () => {
    logger.info({
      msg: "admin-mcp.started",
      port: cfg.PORT,
      sprint: 3,
    });
  });

  const shutdown = async (signal) => {
    logger.info({ msg: "admin-mcp.shutdown", signal });
    server.close(() => {
      pool.end().finally(() => process.exit(0));
    });
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(JSON.stringify({ msg: "admin-mcp.fatal", err: err?.message }));
  process.exit(1);
});
