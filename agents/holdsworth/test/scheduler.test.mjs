import { describe, it, expect, vi } from "vitest";

import { startScheduler } from "../src/scheduler.js";

describe("scheduler", () => {
  it("calls emit on each tick", () => {
    vi.useFakeTimers();
    const emitted = [];
    const s = startScheduler({
      intervalMs: 10,
      emit: (p) => emitted.push(p),
    });

    vi.advanceTimersByTime(35);
    s.stop();

    expect(emitted.length).toBe(3);
    for (const payload of emitted) {
      expect(payload.msg).toBe("scheduler.tick");
      expect(typeof payload.ts).toBe("string");
    }
    vi.useRealTimers();
  });

  it("stops emitting after stop()", () => {
    vi.useFakeTimers();
    const emitted = [];
    const s = startScheduler({
      intervalMs: 10,
      emit: (p) => emitted.push(p),
    });
    vi.advanceTimersByTime(15);
    s.stop();
    vi.advanceTimersByTime(100);
    expect(emitted.length).toBe(1);
    vi.useRealTimers();
  });

  it("manual tick() emits once without advancing the timer", () => {
    const emitted = [];
    const s = startScheduler({
      intervalMs: 999_999,
      emit: (p) => emitted.push(p),
    });
    s.tick();
    s.stop();
    expect(emitted).toHaveLength(1);
  });
});
