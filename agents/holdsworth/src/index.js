// Holdsworth HTTP entry point.
//
// Routes:
//   GET  /healthz              — unauthenticated, preserves the Sprint 2
//                                Dockerfile HEALTHCHECK contract
//   POST /webhooks/sms         — signature-verified SMS provider webhook
//   POST /agent/message        — JWT-guarded agent loop ingress
//
// The scheduler is a heartbeat-only stub; the production scheduler / cron
// layer is proprietary and lives in the private repo.

const express = require("express");
const { z } = require("zod");

const {
  BaseConfigSchema,
  loadConfig,
  buildLogger,
  makePool,
  buildVerifier,
  requireJwt,
} = require("../../shared/node/src");

const { buildSmsHandler } = require("./webhooks/sms");
const { startScheduler } = require("./scheduler");
const { runAgentLoop } = require("./agent-loop");

const ConfigSchema = BaseConfigSchema.extend({
  PORT: z.coerce.number().int().positive().default(8080),
  SMS_PROVIDER_TOKEN: z.string().min(1),
  SCHEDULER_INTERVAL_MS: z.coerce.number().int().positive().default(60_000),
});

async function main() {
  const cfg = loadConfig(ConfigSchema);
  const logger = buildLogger({ level: cfg.LOG_LEVEL, service: "holdsworth" });
  const pool = makePool(cfg.DATABASE_URL);

  const app = express();

  // Healthz first, no body parsing needed.
  app.get("/healthz", (_req, res) => res.status(200).send("ok"));

  // Webhook route: raw body buffer so we can HMAC-verify it exactly as
  // the provider signed it. Must be mounted BEFORE any global
  // express.json() so the Buffer is preserved.
  app.post(
    "/webhooks/sms",
    express.raw({ type: "*/*", limit: "256kb" }),
    buildSmsHandler({
      pool,
      secret: cfg.SMS_PROVIDER_TOKEN,
      logger,
    }),
  );

  app.use(express.json({ limit: "256kb" }));

  // Optional JWT middleware — skipped in dev when Cognito ids aren't set.
  let jwtMiddleware;
  if (cfg.COGNITO_USER_POOL_ID && cfg.COGNITO_USER_POOL_CLIENT_ID) {
    const verifier = buildVerifier({
      userPoolId: cfg.COGNITO_USER_POOL_ID,
      clientId: cfg.COGNITO_USER_POOL_CLIENT_ID,
    });
    jwtMiddleware = requireJwt(verifier);
  } else {
    logger.warn({ msg: "holdsworth.jwt.disabled" });
    jwtMiddleware = (_req, _res, next) => next();
  }

  app.post("/agent/message", jwtMiddleware, async (req, res) => {
    try {
      const userMessage = String(req.body?.message ?? "");
      const history = Array.isArray(req.body?.history) ? req.body.history : [];
      const result = await runAgentLoop({
        userMessage,
        history,
        deps: { pool, logger },
      });
      res.json(result);
    } catch (err) {
      logger.error({ msg: "holdsworth.agent.failed", err: err?.message });
      res.status(500).json({ error: "internal_error" });
    }
  });

  const scheduler = startScheduler({
    intervalMs: cfg.SCHEDULER_INTERVAL_MS,
    emit: (p) => logger.info(p),
  });

  const server = app.listen(cfg.PORT, () => {
    logger.info({ msg: "holdsworth.started", port: cfg.PORT, sprint: 3 });
  });

  const shutdown = (signal) => {
    logger.info({ msg: "holdsworth.shutdown", signal });
    scheduler.stop();
    server.close(() => {
      pool.end().finally(() => process.exit(0));
    });
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(JSON.stringify({ msg: "holdsworth.fatal", err: err?.message }));
  process.exit(1);
});
