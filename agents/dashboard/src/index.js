// Next.js custom server.
//
// The Sprint 2 Dockerfile CMD is `node src/index.js`, so this file is the
// dashboard's entry point. It starts Next.js programmatically and wraps it
// in a thin http.Server that:
//   - Handles GET /healthz with a 200 "ok" plain-text reply before Next.js
//     sees the request (the Sprint 2 Dockerfile HEALTHCHECK expects this).
//   - Delegates every other request to Next's request handler.
//
// The more conventional `next start` invocation is available via
// `npm run start`-style scripts in dev; we use the custom server here so
// the Dockerfile interface (one node entry, port 8080, /healthz) stays
// compatible with the other Node services.

const http = require("node:http");
const next = require("next");

const PORT = Number(process.env.PORT ?? 8080);
const DEV = process.env.NODE_ENV !== "production";

const app = next({ dev: DEV, dir: __dirname + "/.." });
const handle = app.getRequestHandler();

app
  .prepare()
  .then(() => {
    const server = http.createServer((req, res) => {
      if (req.method === "GET" && req.url === "/healthz") {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end("ok");
        return;
      }
      handle(req, res);
    });

    server.listen(PORT, () => {
      // eslint-disable-next-line no-console
      console.log(
        JSON.stringify({
          msg: "dashboard.started",
          port: PORT,
          dev: DEV,
          sprint: 3,
        }),
      );
    });

    const shutdown = (signal) => {
      // eslint-disable-next-line no-console
      console.log(JSON.stringify({ msg: "dashboard.shutdown", signal }));
      server.close(() => process.exit(0));
    };
    process.on("SIGTERM", () => shutdown("SIGTERM"));
    process.on("SIGINT", () => shutdown("SIGINT"));
  })
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error(JSON.stringify({ msg: "dashboard.fatal", err: err?.message }));
    process.exit(1);
  });
