# 🛠️ Awesome Function Calling

A complete, production-oriented reference for **Function Calling**, **Tool Calling**, and **Structured Outputs** across the major LLM providers - OpenAI, Anthropic (Claude), and Google (Gemini).

This repository contains working examples, JSON Schemas, architecture notes, and best practices for 11 real-world tools, plus deep-dive documentation on the concepts that make tool-using agents reliable in production.

---

## 📁 Repository Structure

```
awesome-function-calling/
├── README.md                  <- you are here
├── openai/                    <- OpenAI function calling guide + examples
├── claude/                    <- Anthropic Claude tool use guide + examples
├── gemini/                    <- Google Gemini function calling guide + examples
├── json-output/               <- JSON mode / JSON-only output patterns
├── structured-output/         <- Schema-constrained structured outputs
├── tool-calling/              <- General tool-calling architecture & lifecycle
├── weather/                   <- Weather Tool (full example)
├── calendar/                  <- Calendar Tool (full example)
├── email/                     <- Email Tool (full example)
├── sql/                       <- SQL Tool (full example)
├── excel/                     <- Excel Tool (full example)
├── github/                    <- GitHub Tool (full example)
├── filesystem/                <- Filesystem Tool (full example)
├── web-search/                <- Search Tool (full example)
├── pdf/                       <- PDF Tool (full example)
├── math/                      <- Math Tool (full example)
├── translation/               <- Translation Tool (full example)
├── examples/                  <- Multi-tool / orchestration examples
└── templates/                 <- Reusable schema & handler templates
```

Every tool folder follows the same 10-section format: **Overview, Architecture, JSON Schema, Tool Definition, Input, Output, Example Request, Example Response, Error Handling, Best Practices.**

---

## 📚 Table of Contents

1. [What Is Function Calling?](#1-what-is-function-calling)
2. [What Is Tool Calling?](#2-what-is-tool-calling)
3. [Structured Output](#3-structured-output)
4. [JSON Schema](#4-json-schema)
5. [Validation](#5-validation)
6. [OpenAI: Responses API & Function Calling](#6-openai-responses-api--function-calling)
7. [Claude Tool Use](#7-claude-tool-use)
8. [Gemini Function Calling](#8-gemini-function-calling)
9. [Streaming](#9-streaming)
10. [Parallel Tool Calling](#10-parallel-tool-calling)
11. [Security](#11-security)
12. [Production Best Practices](#12-production-best-practices)

---

## 1. What Is Function Calling?

**Function calling** is a capability that lets a language model produce a structured, machine-readable request to invoke a function defined by the developer, instead of (or in addition to) free-form text.

The model doesn't execute the function itself - it only decides:
- **which** function to call,
- **when** to call it, and
- **what arguments** to pass, validated against a schema you provide.

The calling application is responsible for actually running the function and returning the result back to the model so it can continue reasoning or produce a final answer.

**Typical lifecycle:**

```
User prompt
   │
   ▼
Model reasons about the request
   │
   ▼
Model emits a function call (name + JSON arguments)
   │
   ▼
Your application executes the real function/API/DB call
   │
   ▼
Result is returned to the model as a "tool result" message
   │
   ▼
Model incorporates the result and responds to the user
```

Function calling turns an LLM from a text generator into an **orchestrator** that can query databases, call APIs, read files, send emails, and take real-world actions - all while you retain full control over what code actually executes.

---

## 2. What Is Tool Calling?

"Tool calling" and "function calling" are largely synonymous; **tool calling** is the more general, provider-agnostic term (Anthropic and Google both prefer it) covering any external capability exposed to the model: functions, retrieval systems, code execution, browsing, or MCP (Model Context Protocol) servers.

A **tool** is typically defined by:

| Field | Purpose |
|---|---|
| `name` | Unique, machine-readable identifier |
| `description` | Natural-language explanation the model uses to decide *when* to call it |
| `input_schema` / `parameters` | A JSON Schema describing valid arguments |

Good tool descriptions are the single highest-leverage lever for reliable tool selection - treat them like API documentation written for a very literal reader.

### Single-turn vs multi-turn tool use

- **Single-turn**: one tool call -> one result -> final answer.
- **Multi-turn / agentic**: the model chains multiple tool calls, reasoning between each result, until it has enough information to answer (e.g. "check the weather, then email the forecast to the team").

---

## 3. Structured Output

**Structured output** constrains the model's response to conform to a specific schema - typically JSON - rather than free text. This is used for two distinct purposes:

1. **Tool arguments** - the parameters passed into a function call are always structured (JSON) by design.
2. **Final answers** - forcing the model's *final* response (not just tool calls) into a strict schema, useful for extraction, classification, and data-pipeline tasks.

Providers implement this differently:

| Provider | Mechanism |
|---|---|
| OpenAI | `response_format: { type: "json_schema", strict: true }` (Structured Outputs) |
| Claude | Tool-use "forcing" via `tool_choice` + a single schema-only tool, or prefilled JSON |
| Gemini | `response_mime_type: "application/json"` + `response_schema` |

**Why it matters:** structured output eliminates brittle regex/string parsing of model output and guarantees (or, in Claude/Gemini's case, strongly constrains) the shape of the data your downstream code receives.

See [`json-output/`](./json-output) and [`structured-output/`](./structured-output) for full examples.

---

## 4. JSON Schema

Every tool in this repo is described using standard [JSON Schema](https://json-schema.org/) (draft 2020-12 compatible subset supported by each provider).

Minimal example:

```json
{
  "type": "object",
  "properties": {
    "location": {
      "type": "string",
      "description": "City and country, e.g. 'Paris, France'"
    },
    "units": {
      "type": "string",
      "enum": ["metric", "imperial"],
      "default": "metric"
    }
  },
  "required": ["location"],
  "additionalProperties": false
}
```

**Provider-specific caveats:**
- OpenAI's strict mode requires `additionalProperties: false` and every property to be listed in `required` (use nullable types to simulate optionality).
- Claude supports the full schema but ignores `default`; put defaults in the description or handle them server-side.
- Gemini supports a constrained subset - deeply nested `oneOf`/`anyOf` may not be fully honored, so flatten where possible.

---

## 5. Validation

The model **generating** valid-looking JSON is not the same as your application **trusting** it. Always validate before execution:

1. **Schema validation** - use a JSON Schema validator (`ajv` in JS, `jsonschema`/`pydantic` in Python) on every tool call argument set, even with strict/structured-output modes enabled.
2. **Semantic validation** - schema-valid does not mean *safe* or *sensible* (e.g. a valid date string that's in the past for a "book a future meeting" tool).
3. **Reject-and-report** - on validation failure, return a structured error back to the model as the tool result so it can self-correct, rather than crashing your app.

```python
from jsonschema import validate, ValidationError

try:
    validate(instance=tool_call_args, schema=weather_tool_schema)
except ValidationError as e:
    return {"error": "validation_error", "message": str(e)}
```

See [`templates/error-handling-template.md`](./templates/error-handling-template.md) for a reusable pattern.

---

## 6. OpenAI: Responses API & Function Calling

OpenAI's current recommended interface is the **Responses API** (`/v1/responses`), which unifies chat, tool calling, structured outputs, and built-in tools (web search, file search, code interpreter) under one interface, superseding the older Chat Completions `functions`/`tools` pattern for new projects.

Key concepts:
- Tools are declared as a flat array of `{ type: "function", name, description, parameters }`.
- The model returns `function_call` items with a `call_id`; you execute the function and post back a `function_call_output` item with the matching `call_id`.
- **Structured Outputs** (`strict: true`) guarantee schema-conformant JSON for both tool arguments and final-answer schemas.
- Supports **parallel tool calls** by default (multiple `function_call` items in one response).

See [`openai/README.md`](./openai/README.md) for full request/response examples and code.

---

## 7. Claude Tool Use

Claude (Anthropic) exposes tool use via the Messages API. Tools are declared with `name`, `description`, and `input_schema`. The model returns a `tool_use` content block; you respond with a `tool_result` content block in a follow-up `user` message referencing the same `tool_use_id`.

Key concepts:
- `tool_choice` controls behavior: `auto` (default), `any` (must call a tool), `tool` (force a specific tool), or `none`.
- Claude supports **extended thinking** interleaved with tool calls for complex multi-step reasoning.
- **Fine-grained tool streaming** lets you stream partial JSON arguments as they're generated.
- Claude also supports **client tools** (you execute) and **server tools** (Anthropic executes, e.g. web search, code execution) in the same `tools` array.

See [`claude/README.md`](./claude/README.md) for full request/response examples and code.

---

## 8. Gemini Function Calling

Gemini (Google) declares tools as `FunctionDeclaration` objects grouped inside a `Tool`, passed via the `tools` parameter to `generateContent`.

Key concepts:
- Supports a `mode` on `function_calling_config`: `AUTO`, `ANY` (force a call), or `NONE`.
- Native support for **parallel** and **compositional** (sequential, dependent) function calling.
- `response_schema` + `response_mime_type: "application/json"` provides structured output for final answers.
- Gemini also supports **native tools** like Google Search grounding and code execution alongside custom function declarations.

See [`gemini/README.md`](./gemini/README.md) for full request/response examples and code.

---

## 9. Streaming

Streaming tool calls lets you show partial progress instead of waiting for the full response:

| Provider | Streaming tool-call behavior |
|---|---|
| OpenAI | Server-Sent Events with incremental `function_call_arguments.delta` chunks per `call_id` |
| Claude | `input_json_delta` events inside `content_block_delta`, accumulated per `tool_use` block |
| Gemini | Streamed candidates; function calls typically arrive as a complete chunk rather than token-by-token JSON deltas |

**Pattern:** buffer argument deltas per call ID, and only attempt to parse/execute once you receive the corresponding "stop"/"done" signal for that block - partial JSON is not valid JSON.

```javascript
let buffer = "";
for await (const event of stream) {
  if (event.type === "response.function_call_arguments.delta") {
    buffer += event.delta;
  }
  if (event.type === "response.function_call_arguments.done") {
    const args = JSON.parse(buffer);
    // safe to execute now
  }
}
```

---

## 10. Parallel Tool Calling

All three providers support requesting **multiple tool calls in a single model turn** (e.g. "get the weather in London and Tokyo" -> two `get_weather` calls at once).

**Design implications:**
- Your executor should run independent tool calls **concurrently** (e.g. `Promise.all` / `asyncio.gather`) rather than sequentially.
- Each result must be matched back to its originating call ID - never assume ordering is preserved.
- Partial failure handling: if one of three parallel calls fails, return an error result for that specific call ID while still returning successful results for the others; let the model decide how to proceed.
- Disable parallel calling (`parallel_tool_calls: false` on OpenAI, single `tool_choice` forcing on Claude) when tool calls have side effects that must not happen concurrently (e.g. two calls that both write to the same row).

---

## 11. Security

Tool calling gives a model the ability to trigger real-world side effects - treat every tool as an **attack surface**.

- **Treat model output as untrusted input.** Never string-concatenate model-generated arguments directly into SQL, shell commands, or file paths. Use parameterized queries, allow-lists, and sandboxed execution (see [`sql/`](./sql) and [`filesystem/`](./filesystem)).
- **Principle of least privilege.** Scope API keys/DB credentials used by each tool to the minimum required permissions (read-only where possible).
- **Prompt injection awareness.** Content returned *from* a tool (a web page, a file, an email body) can contain instructions aimed at the model. Never treat tool output as trusted instructions - see the `web-search/` and `email/` examples for mitigation patterns.
- **Human-in-the-loop for irreversible actions.** Sending an email, deleting a file, executing a financial transaction, or modifying access controls should require explicit confirmation before execution, not just a valid tool call.
- **Rate limiting & quotas** per tool, per user, to prevent runaway agentic loops from exhausting downstream APIs or budgets.
- **Audit logging.** Log every tool call (arguments + result + who/when) for traceability, especially for tools with side effects.
- **Schema-level constraints as a security boundary.** Use `enum`, regex `pattern`, and `maxLength` in your JSON Schemas to narrow the attack surface before your code ever runs (e.g. constrain a `table_name` argument to an enum of known tables).

---

## 12. Production Best Practices

- **Write descriptions for the model, not for humans.** Be explicit about units, formats, edge cases, and what *not* to pass.
- **Keep tool surfaces small and composable.** Prefer several narrow, well-named tools over one giant multi-purpose tool with a dozen optional parameters.
- **Return structured errors, not exceptions.** A tool result of `{"error": "not_found", "message": "..."}` lets the model recover gracefully; a raw stack trace does not.
- **Version your tool schemas.** Treat tool definitions like an API contract - breaking changes should bump a version and be rolled out carefully, since prompts and few-shot examples elsewhere may depend on the old shape.
- **Cap iteration loops.** Agentic tool-calling loops should have a hard max-turns limit to prevent infinite loops burning tokens/cost.
- **Test with adversarial inputs.** Malformed dates, SQL-injection-shaped strings, extremely long inputs, and ambiguous natural-language requests should all be part of your test suite.
- **Cache idempotent tool results** where appropriate (e.g. static reference data) to reduce latency and cost.
- **Monitor tool-selection accuracy** in production - track how often the model picks the wrong tool or supplies invalid arguments, and iterate on descriptions/schemas accordingly.
- **Prefer structured output for final answers** whenever your downstream system parses the model's response programmatically - don't regex a natural-language reply.

---

## 🧭 Where to Go Next

- New to the topic? Start with [`tool-calling/README.md`](./tool-calling/README.md) for the end-to-end lifecycle.
- Building on a specific provider? Jump to [`openai/`](./openai), [`claude/`](./claude), or [`gemini/`](./gemini).
- Need a working tool example? Every folder in the tool list above is a complete, copy-pasteable reference implementation.
- Building multi-tool agents? See [`examples/`](./examples) for orchestration patterns.
- Starting a new tool from scratch? Use [`templates/`](./templates) as your starting point.

---

## 📄 License

MIT - free to use, adapt, and extend in your own projects.
