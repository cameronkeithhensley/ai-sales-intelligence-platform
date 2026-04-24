// Sprint 2 stub — real runtime lands in Sprint 3.
const express = require("express");

const app = express();
const PORT = process.env.PORT || 8080;

app.get("/healthz", (_req, res) => res.status(200).send("ok"));

app.get("/", (_req, res) =>
  res.status(200).json({ service: "dashboard", status: "stub", sprint: 2 })
);

app.listen(PORT, () => {
  console.log(
    JSON.stringify({
      msg: "service-started",
      service: "dashboard",
      sprint: 2,
      port: PORT,
    })
  );
});
