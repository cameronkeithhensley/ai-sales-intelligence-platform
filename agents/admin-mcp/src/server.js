// MCP tool registry + Express ingress.
//
// Each tool file in tools/ exports { name, description, inputSchema, handler }.
// server.js wires them to an Express app that exposes:
//   - GET /healthz          — unauthenticated, returns "ok"
//   - POST /mcp/:tool       — JSON body, Zod-validated, JWT-guarded, dispatches to the tool's handler
//
// The MCP JSON-RPC transport from @modelcontextprotocol/sdk can be
// mounted on top of this same Express instance; for the public
// portfolio build we keep the HTTP surface explicit so reviewers can
// POST to it directly from curl.

const express = require("express");

const dispatchScout = require("./tools/dispatch-scout");
const dispatchHarvester = require("./tools/dispatch-harvester");
const dispatchProfiler = require("./tools/dispatch-profiler");
const writeOutreach = require("./tools/write-outreach");
const getJobStatus = require("./tools/get-job-status");
const getSignals = require("./tools/get-signals");

const TOOLS = [
  dispatchScout,
  dispatchHarvester,
  dispatchProfiler,
  writeOutreach,
  getJobStatus,
  getSignals,
];

/**
 * Build an Express app with the MCP tool surface mounted.
 *
 * @param {object} opts
 * @param {object} opts.deps - injected dependencies (audit, tenants, pool, logger)
 * @param {(req, res, next) => void} [opts.jwtMiddleware] - skipped in tests
 * @returns {import('express').Express}
 */
function buildApp({ deps, jwtMiddleware }) {
  const app = express();
  app.use(express.json({ limit: "256kb" }));

  app.get("/healthz", (_req, res) => res.status(200).send("ok"));

  // Catalog endpoint — list registered tools without invoking them.
  app.get("/mcp", (_req, res) => {
    res.json({
      tools: TOOLS.map((t) => ({
        name: t.name,
        description: t.description,
      })),
    });
  });

  for (const tool of TOOLS) {
    const path = `/mcp/${tool.name}`;

    const handlers = [];
    if (jwtMiddleware) handlers.push(jwtMiddleware);

    handlers.push(async (req, res) => {
      const parsed = tool.inputSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          error: "invalid_input",
          issues: parsed.error.issues,
        });
        return;
      }
      try {
        const result = await tool.handler({
          auth: req.auth ?? { sub: "test-bypass" },
          input: parsed.data,
          deps,
        });
        res.json(result);
      } catch (err) {
        deps.logger?.error?.({
          msg: "mcp.tool.failed",
          tool: tool.name,
          err: err?.message,
        });
        res.status(500).json({ error: "internal_error" });
      }
    });

    app.post(path, ...handlers);
  }

  return app;
}

module.exports = { buildApp, TOOLS };
