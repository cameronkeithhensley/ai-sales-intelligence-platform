// Writer SQS consumer.
//
// Thin wrapper over the shared runConsumer. Binds the processor to the
// writer's queue URL and injects the per-service deps.

const { runConsumer } = require("../../shared/node/src/sqs");
const { processJob } = require("./processor");

/**
 * @param {{
 *   queueUrl: string,
 *   anthropic: import('@anthropic-ai/sdk').default,
 *   pool: import('pg').Pool,
 *   logger: { info: Function, error: Function, warn: Function, debug: Function },
 *   concurrency?: number,
 * }} opts
 */
async function startWriterConsumer(opts) {
  const { queueUrl, anthropic, pool, logger, concurrency = 2 } = opts;

  return runConsumer({
    queueUrl,
    concurrency,
    logger,
    async handler(message) {
      await processJob(message, { anthropic, pool, logger });
    },
  });
}

module.exports = { startWriterConsumer };
