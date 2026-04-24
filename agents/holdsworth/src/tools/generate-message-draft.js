// Tool: generate_message_draft
//
// Public-portfolio stub.
//
// Prompt construction lives outside this repository. The production
// implementation assembles a draft from tenant context, channel-specific
// tone, subject-type framing, and policy constraints — none of which
// appear in this file or anywhere else in this public repo.

const { z } = require("zod");

const InputSchema = z.object({
  subject_context: z.object({}).passthrough(),
  channel: z.enum(["email", "sms", "whatsapp"]),
});

module.exports = {
  name: "generate_message_draft",
  inputSchema: InputSchema,

  async handler({ input }) {
    const parsed = InputSchema.parse(input);
    return {
      status: "stubbed",
      channel: parsed.channel,
      draft: null,
    };
  },
};
