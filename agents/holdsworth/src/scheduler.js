// Stub scheduler. Production scheduling / orchestration is proprietary.
//
// This module only sets up a heartbeat interval so the operator can see
// the service is alive in CloudWatch logs. The real scheduler (job
// fan-out, quota enforcement, pipeline sequencing) is proprietary and
// does not live in this repository.

const DEFAULT_INTERVAL_MS = 60_000;

/**
 * Start a heartbeat interval.
 *
 * @param {object} [opts]
 * @param {number} [opts.intervalMs]
 * @param {(payload: object) => void} [opts.emit] Override for tests.
 * @returns {{ stop: () => void, tick: () => void }}
 */
function startScheduler(opts = {}) {
  const { intervalMs = DEFAULT_INTERVAL_MS, emit } = opts;

  function tick() {
    const payload = { msg: "scheduler.tick", ts: new Date().toISOString() };
    if (typeof emit === "function") {
      emit(payload);
    } else {
      // eslint-disable-next-line no-console
      console.log(JSON.stringify(payload));
    }
  }

  const handle = setInterval(tick, intervalMs);

  return {
    tick,
    stop() {
      clearInterval(handle);
    },
  };
}

module.exports = { startScheduler, DEFAULT_INTERVAL_MS };
