// Agent loop skeleton.
//
// The production tool-selection + ranking layer is proprietary and lives
// in the private repo. This module ships a minimal ReAct-shaped wrapper
// so reviewers can see the call shape without any persona, tone, or
// tool-selection heuristics leaking into the public portfolio.
//
// The exported function takes a caller's message + conversation history,
// would normally route it through tool-selection and model inference,
// and returns a placeholder response. The public build never actually
// calls an LLM from this file.

/**
 * @typedef {object} ChatTurn
 * @property {"user"|"assistant"|"tool"} role
 * @property {string} content
 */

/**
 * @param {object} opts
 * @param {string} opts.userMessage
 * @param {ChatTurn[]} [opts.history]
 * @param {object} [opts.deps]
 * @returns {Promise<{ status: string, reply: string, history: ChatTurn[] }>}
 */
async function runAgentLoop({ userMessage, history = [], deps: _deps = {} }) {
  const appendedHistory = [
    ...history,
    { role: "user", content: userMessage },
  ];

  // Tool-selection, memory / dossier load, and model invocation happen
  // here in the production build. In the public scaffold the loop is
  // shape-only and does not call any model or tool.
  const replyText =
    "This is the public portfolio stub. The real agent loop runs outside this repository.";

  return {
    status: "stubbed",
    reply: replyText,
    history: [...appendedHistory, { role: "assistant", content: replyText }],
  };
}

module.exports = { runAgentLoop };
