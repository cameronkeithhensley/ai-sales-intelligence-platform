// Environment variable loading + validation.
//
// Every service declares the subset of fields it needs via loadConfig(schema),
// where `schema` is a Zod object. Missing / malformed values fail fast at
// process start — the task definition is a safer place to catch a typo than
// a 500 from an in-flight request.

const { z } = require("zod");

/**
 * Base fields every service in the platform reads. Service-specific fields
 * are layered on top by the caller.
 */
const BaseConfigSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("production"),
  LOG_LEVEL: z
    .enum(["trace", "debug", "info", "warn", "error", "fatal"])
    .default("info"),
  AWS_REGION: z.string().min(1),
  DATABASE_URL: z.string().min(1),
  COGNITO_USER_POOL_ID: z.string().min(1).optional(),
  COGNITO_USER_POOL_CLIENT_ID: z.string().min(1).optional(),
});

/**
 * Load + validate the process environment against a Zod schema.
 *
 * @param {z.ZodTypeAny} schema Zod schema. Typically BaseConfigSchema.extend({...}).
 * @param {NodeJS.ProcessEnv} [env] Override for tests.
 * @returns {z.infer<typeof schema>}
 */
function loadConfig(schema, env = process.env) {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((i) => `  - ${i.path.join(".")}: ${i.message}`)
      .join("\n");
    throw new Error(`Invalid service configuration:\n${issues}`);
  }
  return parsed.data;
}

module.exports = { BaseConfigSchema, loadConfig };
