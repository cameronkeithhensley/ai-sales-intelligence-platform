// Writer worker entry point.
//
// Boots the SQS consumer. No HTTP server — writer is a worker service
// and does not register with the ALB.

const http = require("node:http");
const { z } = require("zod");

const {
  BaseConfigSchema,
  loadConfig,
  buildLogger,
  makePool,
} = require("../../shared/node/src");

const { buildAnthropicClient } = require("./anthropic-client");
const { startWriterConsumer } = require("./consumer");

const ConfigSchema = BaseConfigSchema.extend({
  QUEUE_URL: z.string().url(),
  ANTHROPIC_API_KEY: z.string().min(1),
  CONCURRENCY: z.coerce.number().int().positive().default(2),
  // Lightweight health-probe port so operators can curl the task while
  // debugging. ECS worker services do not register with an ALB, so this
  // is a convenience, not a contract.
  HEALTH_PORT: z.coerce.number().int().positive().default(8080),
});

async function main() {
  const cfg = loadConfig(ConfigSchema);
  const logger = buildLogger({ level: cfg.LOG_LEVEL, service: "writer" });
  const pool = makePool(cfg.DATABASE_URL);
  const anthropic = buildAnthropicClient(cfg.ANTHROPIC_API_KEY);

  const consumer = await startWriterConsumer({
    queueUrl: cfg.QUEUE_URL,
    anthropic,
    pool,
    logger,
    concurrency: cfg.CONCURRENCY,
  });

  const healthServer = http.createServer((req, res) => {
    if (req.method === "GET" && req.url === "/healthz") {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("ok");
      return;
    }
    res.writeHead(404);
    res.end();
  });
  healthServer.listen(cfg.HEALTH_PORT, () => {
    logger.info({
      msg: "writer.started",
      queue_url: cfg.QUEUE_URL,
      health_port: cfg.HEALTH_PORT,
      concurrency: cfg.CONCURRENCY,
      sprint: 3,
    });
  });

  const shutdown = async (signal) => {
    logger.info({ msg: "writer.shutdown", signal });
    await consumer.stop();
    healthServer.close();
    await pool.end();
    process.exit(0);
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(JSON.stringify({ msg: "writer.fatal", err: err?.message }));
  process.exit(1);
});
