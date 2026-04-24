// Anthropic SDK client construction.
//
// The SDK instance is built once at process start; each job handler
// reuses it. The API key is resolved from Secrets Manager via env
// injection (see agents/writer wiring in terraform/environments/dev).

const Anthropic = require("@anthropic-ai/sdk").default;

/**
 * Build an Anthropic SDK client from ANTHROPIC_API_KEY.
 *
 * @param {string} apiKey
 * @returns {Anthropic}
 */
function buildAnthropicClient(apiKey) {
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY is required for the writer service.");
  }
  return new Anthropic({ apiKey });
}

module.exports = { buildAnthropicClient };
