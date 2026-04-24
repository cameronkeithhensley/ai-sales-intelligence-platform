// Cognito JWT verification.
//
// Uses aws-jwt-verify, which handles JWKS fetch + caching + rotation without
// us reimplementing any of it. Services build a verifier once at startup and
// reuse it across requests; the verifier memoizes the signing keys.

const { CognitoJwtVerifier } = require("aws-jwt-verify");

/**
 * Build a Cognito access-token verifier.
 *
 * @param {object} opts
 * @param {string} opts.userPoolId
 * @param {string} opts.clientId
 * @param {"access"|"id"} [opts.tokenUse] Defaults to "access".
 * @returns {{ verify: (token: string) => Promise<object> }}
 */
function buildVerifier({ userPoolId, clientId, tokenUse = "access" }) {
  const verifier = CognitoJwtVerifier.create({
    userPoolId,
    tokenUse,
    clientId,
  });
  return {
    async verify(token) {
      return verifier.verify(token);
    },
  };
}

/**
 * Pull the bearer token out of an `Authorization: Bearer ...` header.
 * Returns null when missing or malformed.
 *
 * @param {string|undefined} headerValue
 * @returns {string|null}
 */
function extractBearer(headerValue) {
  if (typeof headerValue !== "string") return null;
  const m = headerValue.match(/^Bearer\s+(\S+)\s*$/i);
  return m ? m[1] : null;
}

/**
 * Verify a raw JWT string and return its claims. Throws if invalid.
 *
 * @param {{ verify: (t: string) => Promise<object> }} verifier
 * @param {string} token
 */
async function verifyToken(verifier, token) {
  return verifier.verify(token);
}

/**
 * Express middleware: on a request with a valid bearer, attaches
 * `req.auth = { sub, email, claims }` and calls next(). On missing or
 * invalid, responds 401 and does not call next().
 *
 * @param {{ verify: (t: string) => Promise<object> }} verifier
 */
function requireJwt(verifier) {
  return async function requireJwtMiddleware(req, res, next) {
    const token = extractBearer(req.headers.authorization);
    if (!token) {
      res.status(401).json({ error: "missing_bearer_token" });
      return;
    }
    try {
      const claims = await verifier.verify(token);
      req.auth = {
        sub: claims.sub,
        email: claims.email,
        claims,
      };
      next();
    } catch {
      // Don't leak the verifier's error reason — a 401 is the contract.
      res.status(401).json({ error: "invalid_token" });
    }
  };
}

module.exports = { buildVerifier, extractBearer, verifyToken, requireJwt };
