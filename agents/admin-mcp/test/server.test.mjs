import { describe, it, expect } from "vitest";
import request from "supertest";

import { buildApp } from "../src/server.js";

function mkDeps() {
  const calls = [];
  return {
    calls,
    deps: {
      logger: { error: () => {}, info: () => {} },
      pool: {
        async query() {
          return { rows: [] };
        },
      },
      audit: {
        async record(rec) {
          calls.push(rec);
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

describe("admin-mcp server", () => {
  it("GET /healthz returns 200 ok", async () => {
    const { deps } = mkDeps();
    const app = buildApp({ deps });
    const res = await request(app).get("/healthz");
    expect(res.status).toBe(200);
    expect(res.text).toBe("ok");
  });

  it("GET /mcp returns the tool catalog", async () => {
    const { deps } = mkDeps();
    const app = buildApp({ deps });
    const res = await request(app).get("/mcp");
    expect(res.status).toBe(200);
    const names = res.body.tools.map((t) => t.name).sort();
    expect(names).toEqual([
      "dispatch_harvester",
      "dispatch_profiler",
      "dispatch_scout",
      "get_job_status",
      "get_signals",
      "write_outreach",
    ]);
  });
});
