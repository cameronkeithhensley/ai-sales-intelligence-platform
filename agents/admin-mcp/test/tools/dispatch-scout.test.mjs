import { describe, it, expect } from "vitest";
import request from "supertest";

import { buildApp } from "../../src/server.js";

function mkDeps() {
  const auditCalls = [];
  return {
    auditCalls,
    deps: {
      logger: { error: () => {}, info: () => {} },
      pool: {
        async query() {
          return { rows: [] };
        },
      },
      audit: {
        async record(rec) {
          auditCalls.push(rec);
        },
      },
      tenants: {
        async resolveFromAuth() {
          return { tenantId: "t-1", schemaName: "public" };
        },
      },
    },
  };
}

describe("dispatch_scout tool", () => {
  it("rejects malformed input with 400", async () => {
    const { deps, auditCalls } = mkDeps();
    const app = buildApp({ deps });
    const res = await request(app)
      .post("/mcp/dispatch_scout")
      .send({ subject_type: "not-a-type", subject_id: "also-bad" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("invalid_input");
    expect(auditCalls.length).toBe(0);
  });

  it("records an audit entry on valid input", async () => {
    const { deps, auditCalls } = mkDeps();
    const app = buildApp({ deps });
    const res = await request(app)
      .post("/mcp/dispatch_scout")
      .send({
        subject_type: "company",
        subject_id: "11111111-1111-1111-1111-111111111111",
      });
    expect(res.status).toBe(200);
    const body = JSON.parse(res.body.content[0].text);
    expect(body.status).toBe("stubbed");
    expect(body.job_id).toMatch(/^[0-9a-f-]{36}$/i);

    expect(auditCalls).toHaveLength(1);
    expect(auditCalls[0]).toMatchObject({
      tenantId: "t-1",
      agent: "scout",
      action: "tool.dispatch_scout",
      outcome: "allowed",
    });
  });

  it("returns the same tool catalog shape the other tools emit", async () => {
    const { deps } = mkDeps();
    const app = buildApp({ deps });
    const res = await request(app).get("/mcp");
    const names = res.body.tools.map((t) => t.name);
    expect(names).toContain("dispatch_scout");
  });
});
