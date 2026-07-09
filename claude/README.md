# Claude — Tool Use (Anthropic Messages API)

## Overview

Claude models support tool use via the Messages API (`POST /v1/messages`). Tools are declared with `name`, `description`, and `input_schema` (standard JSON Schema). Claude returns a `tool_use` content block; your application executes it and replies with a `tool_result` block.

## Core Concepts

- `tool_choice`: `{"type": "auto"}` (default), `{"type": "any"}` (must use one of the tools), `{"type": "tool", "name": "..."}` (force a specific tool), or `{"type": "none"}`.
- Tool results are sent back as a `user` message containing a `tool_result` content block referencing the `tool_use_id`.
- Claude supports **client tools** (executed by you) and **server tools** (executed by Anthropic, e.g. web search) in the same request.
- **Extended thinking** can be interleaved with tool calls for complex multi-step agentic tasks.

## Tool Definition

```json
{
  "name": "get_weather",
  "description": "Get the current weather for a given city. Returns temperature in Celsius and a short condition string.",
  "input_schema": {
    "type": "object",
    "properties": {
      "location": { "type": "string", "description": "City and country, e.g. 'Berlin, Germany'" },
      "units": { "type": "string", "enum": ["metric", "imperial"], "description": "Defaults to metric if omitted" }
    },
    "required": ["location"]
  }
}
```

## Example Request

```javascript
const response = await fetch("https://api.anthropic.com/v1/messages", {
  method: "POST",
  headers: {
    "x-api-key": process.env.ANTHROPIC_API_KEY,
    "anthropic-version": "2023-06-01",
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    tools: [weatherToolDefinition],
    messages: [{ role: "user", content: "What's the weather in Tokyo?" }]
  })
});
```

## Example Response (model requests a tool call)

```json
{
  "id": "msg_01Xyz",
  "content": [
    { "type": "text", "text": "I'll check the weather for you." },
    {
      "type": "tool_use",
      "id": "toolu_01A2b3",
      "name": "get_weather",
      "input": { "location": "Tokyo, Japan", "units": "metric" }
    }
  ],
  "stop_reason": "tool_use"
}
```

## Sending the Tool Result Back

```javascript
const followUp = await fetch("https://api.anthropic.com/v1/messages", {
  method: "POST",
  headers: { "x-api-key": process.env.ANTHROPIC_API_KEY, "anthropic-version": "2023-06-01", "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    tools: [weatherToolDefinition],
    messages: [
      { role: "user", content: "What's the weather in Tokyo?" },
      { role: "assistant", content: previousResponse.content },
      {
        role: "user",
        content: [
          {
            type: "tool_result",
            tool_use_id: "toolu_01A2b3",
            content: JSON.stringify({ temperature: 26, condition: "Clear" })
          }
        ]
      }
    ]
  })
});
```

## Structured Output via Forced Tool Use

Claude has no dedicated "JSON mode" — the idiomatic pattern is to define a single schema-only tool and force it with `tool_choice`:

```json
{
  "tool_choice": { "type": "tool", "name": "emit_weather_summary" },
  "tools": [{
    "name": "emit_weather_summary",
    "description": "Emit the final structured weather summary.",
    "input_schema": {
      "type": "object",
      "properties": {
        "city": { "type": "string" },
        "temperature_c": { "type": "number" },
        "advice": { "type": "string" }
      },
      "required": ["city", "temperature_c", "advice"]
    }
  }]
}
```

## Streaming

Set `"stream": true`. Watch for `content_block_delta` events with `delta.type === "input_json_delta"`, accumulating the `partial_json` string per content block index until `content_block_stop`.

## Parallel Tool Calls

Claude may emit multiple `tool_use` blocks in a single response. Execute independent calls concurrently and return one `tool_result` block per `tool_use_id` in the same follow-up `user` message.

## Error Handling

- If your function execution fails, return a `tool_result` with `"is_error": true` and a short message — Claude will incorporate this and can retry or ask the user for clarification.
- Malformed/missing arguments (rare with well-written schemas) should be validated before execution and treated the same way.

## Best Practices

- Write tool `description`s as if documenting an API for a new engineer — include units, formats, and what to do with ambiguous input.
- Use forced `tool_choice` for tasks that are purely extraction/structuring, to guarantee a tool call happens.
- For agentic loops, cap the number of tool-use round trips and surface a fallback message if the limit is hit.
