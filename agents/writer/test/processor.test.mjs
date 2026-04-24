import { describe, it, expect, vi } from "vitest";

import { processJob } from "../src/processor.js";

function mkDeps() {
  const createSpy = vi.fn(async () => ({
    id: "msg_stub",
    usage: { input_tokens: 10, output_tokens: 5 },
  }));
  return {
    createSpy,
    deps: {
      anthropic: { messages: { create: createSpy } },
      pool: { query: vi.fn() },
      logger: { info: vi.fn(), error: vi.fn() },
    },
  };
}

describe("writer processor", () => {
  it("extracts job_id, invokes anthropic once, and returns 'stubbed'", async () => {
    const { deps, createSpy } = mkDeps();
    const message = {
      MessageId: "aws-msg-1",
      Body: JSON.stringify({
        job_id: "11111111-1111-1111-1111-111111111111",
        tenant_id: "22222222-2222-2222-2222-222222222222",
        agent: "writer",
        subject_type: "company",
        enqueued_at: "2026-04-24T00:00:00Z",
        policy_version: "0.0.0",
        payload: {},
      }),
    };

    const result = await processJob(message, deps);

    expect(result).toEqual({
      status: "stubbed",
      job_id: "11111111-1111-1111-1111-111111111111",
    });
    expect(createSpy).toHaveBeenCalledTimes(1);
    const call = createSpy.mock.calls[0][0];
    expect(call.model).toMatch(/^claude-/);
    expect(Array.isArray(call.messages)).toBe(true);
    // The stub deliberately sends the placeholder sentinel; real
    // prompt content does not appear in this repo.
    expect(call.messages[0].content).toBe(
      "[PROMPT CONTENT EXCLUDED FROM PUBLIC REPO]",
    );
  });

  it("propagates parse errors when message body is malformed", async () => {
    const { deps } = mkDeps();
    const bad = { MessageId: "aws-msg-2", Body: "not-json" };
    await expect(processJob(bad, deps)).rejects.toThrow();
  });
});
