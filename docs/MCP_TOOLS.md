# MCP Tools

> Overview of the Admin MCP server and the **shape** of the tools it exposes. Tool implementations, parameter schemas, and business rules are intentionally out of scope.

---

## The Admin MCP server

The Admin MCP server is an internal orchestration surface that exposes operator capabilities through the [Model Context Protocol](https://modelcontextprotocol.io/). It is not customer-facing — it is the interface an operator (or an operator's AI assistant) uses to configure, dispatch, and inspect the platform.

- **Runtime:** Node.js 20, `@modelcontextprotocol/sdk`.
- **Auth:** Cognito OIDC JWT. The JWT resolves to a tenant row, and tools are constructed with that tenant context baked in.
- **Request model:** stateless. Each incoming MCP request constructs a fresh `McpServer` instance, registers the tools the calling tenant is authorized to use, and disposes after the call. No shared state across requests.
- **Dispatch:** most tools produce SQS jobs on the appropriate agent queue; a few are direct DB reads or config writes.

---

## Tool-shape pattern

Every tool follows the same basic pattern:

1. **Authorize** — derive tenant and tier from the validated JWT; reject if the tool is not available at the caller's tier.
2. **Validate** — parse arguments with Zod; reject malformed input with a structured error.
3. **Resolve config** — merge defaults → tenant-specific DB overrides → per-call argument overrides.
4. **Act** — either enqueue an SQS job (and return the `job_id` for later polling) or perform a bounded DB read / config write inline.
5. **Log** — record the call in `audit_log` with the policy version in effect.

Tools that enqueue jobs return a `job_id`. The caller polls `job_results` (or uses a status tool) to observe completion.

---

## Tool surface (names and purposes)

The server exposes tools in the following categories. Specific tool names track the operator UX and evolve sprint-to-sprint.

### Dispatch tools

- **Dispatch Scout** — enqueue a public-source scraping job.
- **Dispatch Harvester** — enqueue an external-data aggregation job.
- **Dispatch Profiler** — enqueue a passive-OSINT dossier job for a subject.
- **Write Outreach** — generate a drafted outreach message for a given prospect context.
- **Revise Outreach** — produce a revised draft given feedback on a prior draft.

### Read / status tools

- **Get Job Status** — look up the current status and, if complete, result payload of a prior job.
- **Get Signals** — return recent intent signals for the tenant, with pagination.
- **Get Lead Scores** — return current ranking metadata for the tenant's lead set. (Implementation rules are proprietary; the tool surface returns an opaque ordering.)

### Configuration tools

- **Configure Scout** — adjust the tenant's Scout parameters.
- **Configure Harvester** — adjust the tenant's Harvester parameters.
- **Configure Writer** — adjust Writer tone and constraints at the tenant level.
- **Configure Service Area** — set the tenant's geographic scope.
- **Configure Integration** — connect a third-party integration (CRM provider, email delivery provider, SMS provider, ad platform API). Actual provider identity is abstracted at the tool layer.
- **Configure Email** — set sender identity and delivery preferences.
- **Configure Reviews** — connect review platform API sources.
- **Configure Competitors** — set the tenant's competitor watchlist.
- **Configure Ad Budget** — set ad platform API budget caps.

### Operational tools

- **Run Signal Discovery** — kick off a full signal-discovery cycle for the tenant (wraps multiple dispatches).
- **Manage Category Requests** — review and act on tenant requests to expand their category coverage.

---

## What is deliberately not in this document

- The exact Zod schemas for tool inputs and outputs.
- The configuration merge rules (defaults → overrides) in any specific detail.
- The tier-gate matrix that maps subscription tiers to available tools.
- The signal-discovery cycle sequencing, quota logic, or scoring rules that underlie `Run Signal Discovery` and `Get Lead Scores`.
- Prompt content used by `Write Outreach` and `Revise Outreach`.
