// Structured JSON logger.
//
// Redact list MUST stay in sync with the known-secret env var names across
// the platform. If a new secret env var is added to any service, add it
// here before committing. The redact paths use pino's glob syntax; each
// entry covers the field appearing anywhere in a log payload.

const pino = require("pino");

const REDACT_PATHS = [
  "*.DATABASE_URL",
  "*.JWT_SIGNING_KEY",
  "*.ANTHROPIC_API_KEY",
  "*.SMS_PROVIDER_TOKEN",
  "*.EMAIL_DELIVERY_PROVIDER_TOKEN",
  "*.PERSON_DATA_API_KEY",
  "*.password",
  "*.secret",
  "*.authorization",
  "*.cookie",
  "req.headers.authorization",
  "req.headers.cookie",
];

/**
 * Build a configured pino logger.
 *
 * @param {object} [opts]
 * @param {string} [opts.level] Override LOG_LEVEL.
 * @param {string} [opts.service] Adds a stable `service` field to every log.
 * @param {string[]} [opts.extraRedactPaths] Service-specific redactions.
 * @returns {import('pino').Logger}
 */
function buildLogger(opts = {}) {
  const { level = process.env.LOG_LEVEL || "info", service, extraRedactPaths = [] } = opts;

  return pino({
    level,
    base: service ? { service } : undefined,
    redact: {
      paths: [...REDACT_PATHS, ...extraRedactPaths],
      censor: "[redacted]",
    },
    timestamp: pino.stdTimeFunctions.isoTime,
  });
}

module.exports = { buildLogger, REDACT_PATHS };
