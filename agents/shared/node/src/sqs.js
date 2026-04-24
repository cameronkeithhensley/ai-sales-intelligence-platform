// Long-polling SQS consumer with visibility-timeout heartbeat.
//
// runConsumer long-polls the queue with WaitTimeSeconds=20 (the SQS
// maximum) to keep ReceiveMessage cost / empty-poll noise low. Up to
// `concurrency` handlers run in parallel. For each in-flight message a
// heartbeat timer calls ChangeMessageVisibility every
// `visibilityHeartbeatSeconds` so a long-running job does not have its
// message re-delivered to a sibling worker. On handler success, the
// message is deleted. On handler failure, the message is released back
// to the queue (by clearing the heartbeat and letting visibility expire)
// — the SQS module's redrive_policy bounds re-delivery.

const {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
  ChangeMessageVisibilityCommand,
} = require("@aws-sdk/client-sqs");

/**
 * Run a long-polling consumer loop. Returns a stop() function that drains
 * in-flight handlers before resolving.
 *
 * @param {object} opts
 * @param {string} opts.queueUrl
 * @param {(msg: import('@aws-sdk/client-sqs').Message) => Promise<void>} opts.handler
 * @param {SQSClient} [opts.client] Default: new SQSClient().
 * @param {number} [opts.concurrency] Max in-flight handlers. Default 4.
 * @param {number} [opts.visibilityHeartbeatSeconds] Heartbeat interval. Default 30.
 * @param {number} [opts.visibilityExtensionSeconds] ChangeMessageVisibility.VisibilityTimeout. Default 60.
 * @param {import('pino').Logger} [opts.logger] For structured logs.
 * @param {() => boolean} [opts.shouldStop] Hook for tests / shutdown. Default always-false.
 * @returns {Promise<{ stop: () => Promise<void> }>}
 */
async function runConsumer(opts) {
  const {
    queueUrl,
    handler,
    client = new SQSClient({}),
    concurrency = 4,
    visibilityHeartbeatSeconds = 30,
    visibilityExtensionSeconds = 60,
    logger = null,
    shouldStop = () => false,
  } = opts;

  let stopping = false;
  const inflight = new Set();

  function log(level, payload) {
    if (logger && typeof logger[level] === "function") {
      logger[level](payload);
    }
  }

  async function handleOne(message) {
    const heartbeat = setInterval(() => {
      client
        .send(
          new ChangeMessageVisibilityCommand({
            QueueUrl: queueUrl,
            ReceiptHandle: message.ReceiptHandle,
            VisibilityTimeout: visibilityExtensionSeconds,
          }),
        )
        .catch((err) => {
          log("warn", {
            msg: "sqs.heartbeat.failed",
            message_id: message.MessageId,
            err: err?.message,
          });
        });
    }, visibilityHeartbeatSeconds * 1000);

    try {
      await handler(message);
      await client.send(
        new DeleteMessageCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle,
        }),
      );
      log("debug", { msg: "sqs.message.completed", message_id: message.MessageId });
    } catch (err) {
      log("error", {
        msg: "sqs.handler.failed",
        message_id: message.MessageId,
        err: err?.message,
      });
      // Intentional: do not delete. Visibility expires, redrive policy
      // bounds re-delivery count.
    } finally {
      clearInterval(heartbeat);
    }
  }

  async function pollOnce() {
    const waitSlots = concurrency - inflight.size;
    if (waitSlots <= 0) {
      // Concurrency full — wait for at least one to finish.
      await Promise.race(inflight);
      return;
    }

    const resp = await client.send(
      new ReceiveMessageCommand({
        QueueUrl: queueUrl,
        MaxNumberOfMessages: Math.min(waitSlots, 10),
        WaitTimeSeconds: 20,
        VisibilityTimeout: visibilityExtensionSeconds,
      }),
    );

    for (const message of resp.Messages ?? []) {
      const p = handleOne(message).finally(() => inflight.delete(p));
      inflight.add(p);
    }
  }

  // Fire-and-await loop. The caller can stop via the returned stop().
  (async () => {
    while (!stopping && !shouldStop()) {
      try {
        await pollOnce();
      } catch (err) {
        log("error", { msg: "sqs.poll.failed", err: err?.message });
        await new Promise((r) => setTimeout(r, 1000));
      }
    }
  })();

  return {
    async stop() {
      stopping = true;
      await Promise.allSettled([...inflight]);
    },
  };
}

module.exports = { runConsumer };
