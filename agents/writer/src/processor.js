// Writer job processor.
//
// Shape-only. The production implementation performs prompt assembly,
// tone selection, personalization, and output validation — all of which
// are proprietary and live in the private repo. This stub keeps the
// SQS -> DB -> Anthropic flow visible without leaking any prompt or
// persona material.

/**
 * @param {{ Body: string, MessageId?: string }} message
 * @param {{
 *   anthropic: import('@anthropic-ai/sdk').default,
 *   pool: import('pg').Pool,
 *   logger: { info: Function, error: Function },
 *   model?: string,
 * }} deps
 */
async function processJob(message, { anthropic, pool, logger, model = "claude-sonnet-4-6" }) {
  const job = JSON.parse(message.Body);
  logger.info({ msg: "writer.job.received", job_id: job.job_id });

  // …tenant resolution, dossier load, and prompt assembly would happen
  // here in the production build. None of that is reproduced in this
  // public portfolio repo.

  const response = await anthropic.messages.create({
    model,
    max_tokens: 512,
    messages: [
      { role: "user", content: "[PROMPT CONTENT EXCLUDED FROM PUBLIC REPO]" },
    ],
  });

  logger.info({
    msg: "writer.job.completed",
    job_id: job.job_id,
    tokens: response.usage,
  });

  // …persist result to public.jobs here in the production build. Left
  // out of the stub so the flow remains obviously shape-only.
  void pool; // referenced to make the dependency contract explicit

  return { status: "stubbed", job_id: job.job_id };
}

module.exports = { processJob };
