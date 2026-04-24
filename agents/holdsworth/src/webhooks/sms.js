// SMS webhook handler.
//
// Providers sign their webhooks with an HMAC so the receiver can verify
// the request came from them and was not tampered with in flight. The
// specific header name + hash algorithm is vendor-dependent; this file
// implements the canonical SHA-256 over the raw request body with a
// constant-time comparison against an `X-Signature` header. The shared
// token lives in Secrets Manager and is injected as SMS_PROVIDER_TOKEN
// (see the ecs-service wiring for holdsworth in terraform/environments).

const crypto = require("node:crypto");

/**
 * Verify an HMAC-SHA256 signature over the raw request body.
 *
 * @param {Buffer|string} rawBody
 * @param {string|undefined} providedHex
 * @param {string} secret
 * @returns {boolean}
 */
function verifySignature(rawBody, providedHex, secret) {
  if (!providedHex || typeof providedHex !== "string") return false;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(rawBody)
    .digest("hex");
  const a = Buffer.from(expected, "hex");
  const b = Buffer.from(providedHex, "hex");
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/**
 * Build an Express handler bound to a Postgres pool (for audit) and the
 * webhook secret. Mount with:
 *
 *   app.post(
 *     "/webhooks/sms",
 *     express.raw({ type: "*\/*" }),  // keep body as a Buffer for HMAC
 *     buildSmsHandler({ pool, secret })
 *   );
 *
 * The handler records every verified webhook in public.outreach_events
 * and returns 200; unverified webhooks get 401 with no body.
 */
function buildSmsHandler({ pool, secret, logger }) {
  return async function smsWebhookHandler(req, res) {
    const raw = Buffer.isBuffer(req.body) ? req.body : Buffer.from("");
    const signature = req.header("X-Signature");

    if (!verifySignature(raw, signature, secret)) {
      if (logger) logger.warn({ msg: "holdsworth.webhook.sms.bad_signature" });
      res.status(401).send();
      return;
    }

    let payload = {};
    try {
      payload = JSON.parse(raw.toString("utf8"));
    } catch {
      // Accept non-JSON bodies as signed opaque payloads; downstream
      // consumers decide what to do with them.
    }

    // The specific event payload shape is vendor-dependent. The shared
    // contract is: a provider_message_id identifying the outbound
    // message, a destination contact_value, an event_type (delivered /
    // bounced / complaint / ...), and optional subject_line. Unknown
    // fields are persisted into metadata.
    const tenantId = req.header("X-Tenant-Id") ?? null;
    try {
      await pool.query(
        `INSERT INTO public.outreach_events (
           tenant_id, contact_type, contact_value, event_type,
           provider_message_id, subject_line, metadata
         ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          tenantId,
          "sms",
          payload.to ?? payload.contact_value ?? "",
          payload.event_type ?? "delivered",
          payload.provider_message_id ?? null,
          null,
          JSON.stringify(payload),
        ],
      );
    } catch (err) {
      if (logger) {
        logger.error({
          msg: "holdsworth.webhook.sms.persist_failed",
          err: err?.message,
        });
      }
      res.status(500).send();
      return;
    }

    res.status(200).json({ ok: true });
  };
}

module.exports = { buildSmsHandler, verifySignature };
