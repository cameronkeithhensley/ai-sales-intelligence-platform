# Module: sqs

A map-driven SQS module: callers pass a `queues` map keyed by logical queue
name, and each entry gets a main queue and a matching DLQ with a redrive
policy wiring them together. Adding a new agent queue is a one-entry change
to the map.

## Why one queue per agent stage

The platform runs a pipeline of small agents (scout → harvester → profiler
→ writer) where each stage does a qualitatively different thing — HTTP
scraping, LLM inference, email composition, and so on. Giving every stage
its own queue means each stage can be tuned and scaled independently:

- **Back-pressure isolation.** A stall or poison message in the writer
  queue does not choke the scout pipeline behind it. Each queue's DLQ
  surfaces only its own failures.
- **Per-stage visibility timeouts.** Scout jobs finish in seconds; writer
  jobs call an LLM and can take 30–60s. A single shared queue would force
  either excessive re-delivery of fast jobs or starvation of slow ones.
- **Independent scaling.** ECS services scale off queue depth; per-queue
  CloudWatch metrics mean each service scales to its own workload.
- **Blast radius.** If a third-party API is broken, the stage that depends
  on it can drain to its DLQ without taking the other stages down.

## Inputs (summary)

| Name | Purpose |
|---|---|
| `queues` | Map of queue name -> `{ visibility_timeout_seconds, message_retention_seconds, max_receive_count }`. |
| `dlq_message_retention_seconds` | Retention for DLQs (default 14 days, the SQS maximum). |
| `kms_master_key_id` | SSE-KMS key. Default `alias/aws/sqs` (AWS-managed SQS key). |
| `environment` / `tags` | Tagging. |

## Outputs (summary)

`queue_arns`, `queue_urls`, `queue_ids`, `dlq_arns`, `dlq_urls` — each a map
keyed by the logical queue name.

## Design choices

### DLQ pattern

Every main queue gets a `{name}-dlq` DLQ created alongside it. Messages that
exceed `max_receive_count` redeliveries land on the DLQ, where they sit for
up to 14 days for inspection. DLQs do not themselves have a DLQ — that would
be infinite regress.

A `redrive_allow_policy` locks each DLQ to accept re-drives only from its
paired main queue, which closes the default "any principal may move
messages off my DLQ" hole that exists on plain SQS queues.

### Typical `max_receive_count`

- **Fast, idempotent HTTP pulls:** 3–5. A transient network blip gets
  retried; a genuinely bad message is quarantined quickly.
- **LLM / expensive calls:** 2–3. Each retry costs real money, and LLM
  errors rarely resolve themselves within seconds.
- **Cron / fan-out messages:** 3.

### Visibility timeout guidance

Set it to roughly 6x the 90th-percentile processing time of the stage.
Shorter and SQS redelivers in-flight messages to another worker, causing
double-processing; longer and a genuine crash takes 6x longer to recover.

### Encryption

`kms_master_key_id` defaults to the AWS-managed SQS key. Consumers / producers
inside the account do not need any extra IAM grants to use it. For
cross-account producers or a stricter audit posture, pass a customer-managed
key ARN.
