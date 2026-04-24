import { describe, it, expect } from "vitest";
import { quoteIdent } from "../src/db.js";

describe("quoteIdent", () => {
  it("accepts a valid lowercase identifier", () => {
    expect(quoteIdent("tenant_abc123")).toBe('"tenant_abc123"');
  });

  it("accepts single-letter identifier", () => {
    expect(quoteIdent("t")).toBe('"t"');
  });

  it("rejects identifiers starting with a digit", () => {
    expect(() => quoteIdent("1bad")).toThrow(/Invalid SQL identifier/);
  });

  it("rejects identifiers with uppercase letters", () => {
    expect(() => quoteIdent("Tenant")).toThrow(/Invalid SQL identifier/);
  });

  it("rejects SQL injection attempts via dash / semicolon / space", () => {
    expect(() => quoteIdent('x"; DROP TABLE users; --')).toThrow(
      /Invalid SQL identifier/,
    );
    expect(() => quoteIdent("tenant; DROP")).toThrow(/Invalid SQL identifier/);
    expect(() => quoteIdent("tenant-abc")).toThrow(/Invalid SQL identifier/);
    expect(() => quoteIdent("")).toThrow(/Invalid SQL identifier/);
  });

  it("rejects non-string inputs", () => {
    expect(() => quoteIdent(undefined)).toThrow(/Invalid SQL identifier/);
    expect(() => quoteIdent(42)).toThrow(/Invalid SQL identifier/);
    expect(() => quoteIdent(null)).toThrow(/Invalid SQL identifier/);
  });

  it("rejects identifiers longer than 63 characters", () => {
    const long = "a".repeat(64);
    expect(() => quoteIdent(long)).toThrow(/Invalid SQL identifier/);
  });
});
