import { describe, it, expect } from "vitest";
import { z } from "zod";
import { BaseConfigSchema, loadConfig } from "../src/config.js";

describe("loadConfig", () => {
  it("parses a valid minimal env", () => {
    const cfg = loadConfig(BaseConfigSchema, {
      NODE_ENV: "production",
      LOG_LEVEL: "info",
      AWS_REGION: "us-east-1",
      DATABASE_URL: "postgres://user:pw@host:5432/db",
    });
    expect(cfg.AWS_REGION).toBe("us-east-1");
    expect(cfg.LOG_LEVEL).toBe("info");
  });

  it("throws with an aggregated message on missing required fields", () => {
    expect(() => loadConfig(BaseConfigSchema, {})).toThrow(
      /Invalid service configuration/,
    );
  });

  it("allows services to extend the base schema", () => {
    const ServiceSchema = BaseConfigSchema.extend({
      QUEUE_URL: z.string().url(),
    });
    const cfg = loadConfig(ServiceSchema, {
      AWS_REGION: "us-east-1",
      DATABASE_URL: "postgres://x",
      QUEUE_URL: "https://sqs.us-east-1.amazonaws.com/000000000000/dev-scout",
    });
    expect(cfg.QUEUE_URL).toMatch(/^https:\/\//);
  });
});
