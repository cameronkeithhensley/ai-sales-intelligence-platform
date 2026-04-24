import { describe, it, expect } from "vitest";
import { extractBearer, requireJwt } from "../src/jwt.js";

describe("extractBearer", () => {
  it("extracts a bearer token from a valid header", () => {
    expect(extractBearer("Bearer abc.def.ghi")).toBe("abc.def.ghi");
  });

  it("is case-insensitive on the scheme", () => {
    expect(extractBearer("bearer abc.def.ghi")).toBe("abc.def.ghi");
  });

  it("returns null for missing / malformed headers", () => {
    expect(extractBearer(undefined)).toBeNull();
    expect(extractBearer("")).toBeNull();
    expect(extractBearer("abc.def.ghi")).toBeNull();
    expect(extractBearer("Basic abc")).toBeNull();
  });
});

describe("requireJwt middleware", () => {
  function mockRes() {
    const res = {
      statusCode: 200,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(payload) {
        this.body = payload;
        return this;
      },
    };
    return res;
  }

  it("responds 401 when no bearer is present", async () => {
    const mw = requireJwt({ verify: async () => ({ sub: "u1" }) });
    const req = { headers: {} };
    const res = mockRes();
    let nextCalled = false;
    await mw(req, res, () => {
      nextCalled = true;
    });
    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "missing_bearer_token" });
    expect(nextCalled).toBe(false);
  });

  it("responds 401 when the verifier throws", async () => {
    const mw = requireJwt({
      verify: async () => {
        throw new Error("bad sig");
      },
    });
    const req = { headers: { authorization: "Bearer xxx" } };
    const res = mockRes();
    let nextCalled = false;
    await mw(req, res, () => {
      nextCalled = true;
    });
    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "invalid_token" });
    expect(nextCalled).toBe(false);
  });

  it("attaches req.auth and calls next on valid token", async () => {
    const claims = { sub: "user-1", email: "u@example.com", scope: "openid" };
    const mw = requireJwt({ verify: async () => claims });
    const req = { headers: { authorization: "Bearer good" } };
    const res = mockRes();
    let nextCalled = false;
    await mw(req, res, () => {
      nextCalled = true;
    });
    expect(nextCalled).toBe(true);
    expect(req.auth).toEqual({
      sub: "user-1",
      email: "u@example.com",
      claims,
    });
  });
});
