import { describe, it, expect, beforeEach } from "vitest";
import express from "express";
import request from "supertest";
import crypto from "node:crypto";

import { buildSmsHandler, verifySignature } from "../src/webhooks/sms.js";

function sign(body, secret) {
  return crypto.createHmac("sha256", secret).update(body).digest("hex");
}

function buildApp({ pool, secret }) {
  const app = express();
  app.post(
    "/webhooks/sms",
    express.raw({ type: "*/*", limit: "256kb" }),
    buildSmsHandler({ pool, secret, logger: null }),
  );
  return app;
}

describe("SMS webhook", () => {
  const SECRET = "hunter2-example";

  let queries;
  let app;

  beforeEach(() => {
    queries = [];
    const pool = {
      async query(sql, params) {
        queries.push({ sql, params });
        return { rowCount: 1, rows: [] };
      },
    };
    app = buildApp({ pool, secret: SECRET });
  });

  it("rejects an unsigned request with 401", async () => {
    const res = await request(app)
      .post("/webhooks/sms")
      .set("Content-Type", "application/json")
      .send({ event_type: "delivered" });
    expect(res.status).toBe(401);
    expect(queries).toHaveLength(0);
  });

  it("rejects a wrongly-signed request with 401", async () => {
    const raw = '{"event_type":"delivered"}';
    const res = await request(app)
      .post("/webhooks/sms")
      .set("Content-Type", "application/json")
      .set("X-Signature", sign(raw, "wrong-secret"))
      .send(raw);
    expect(res.status).toBe(401);
    expect(queries).toHaveLength(0);
  });

  it("accepts a correctly-signed request and persists an outreach_events row", async () => {
    const raw =
      '{"provider_message_id":"abc-123","event_type":"delivered","to":"+10000000000"}';
    const res = await request(app)
      .post("/webhooks/sms")
      .set("Content-Type", "application/json")
      .set("X-Signature", sign(raw, SECRET))
      .set("X-Tenant-Id", "00000000-0000-0000-0000-000000000001")
      .send(raw);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });

    expect(queries).toHaveLength(1);
    expect(queries[0].sql).toMatch(/INSERT INTO public\.outreach_events/);
    expect(queries[0].params).toEqual([
      "00000000-0000-0000-0000-000000000001",
      "sms",
      "+10000000000",
      "delivered",
      "abc-123",
      null,
      expect.stringContaining("provider_message_id"),
    ]);
  });
});

describe("verifySignature", () => {
  it("returns false on missing signature", () => {
    expect(verifySignature("body", undefined, "secret")).toBe(false);
  });

  it("returns false on signature length mismatch", () => {
    expect(verifySignature("body", "short", "secret")).toBe(false);
  });

  it("returns true on a valid HMAC", () => {
    const secret = "s";
    const body = "payload";
    const sig = crypto.createHmac("sha256", secret).update(body).digest("hex");
    expect(verifySignature(body, sig, secret)).toBe(true);
  });
});
