# OpenAI — Function Calling & the Responses API

## Overview

OpenAI models (GPT-4.1, GPT-4o, o-series, etc.) support function calling through the **Responses API** (`POST /v1/responses`), the current recommended interface, as well as the legacy Chat Completions `tools` parameter. This guide uses the Responses API.

## Core Concepts

- Tools are declared as flat objects: `{ type: "function", name, description, parameters, strict }`.
- The model returns one or more `function_call` output items, each with a unique `call_id`.
- You execute the function yourself and send the result back as a `function_call_output` item in the next request, referencing the same `call_id`.
- `strict: true` + a fully-specified JSON Schema enables **Structured Outputs**, guaranteeing schema-conformant arguments.

## Tool Definition

```json
{
  "type": "function",
  "name": "get_weather",
  "description": "Get the current weather for a given city.",
  "strict": true,
  "parameters": {
    "type": "object",
    "properties": {
      "location": { "type": "string", "description": "City and country, e.g. 'Berlin, Germany'" },
      "units": { "type": "string", "enum": ["metric", "imperial"] }
    },
    "required": ["location", "units"],
    "additionalProperties": false
  }
}
```

## Example Request

```javascript
const response = await fetch("https://api.openai.com/v1/responses", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "gpt-4.1",
    input: [{ role: "user", content: "What's the weather in Tokyo?" }],
    tools: [weatherToolDefinition],
    parallel_tool_calls: true
  })
});
```

## Example Response (model requests a tool call)

```json
{
  "id": "resp_abc123",
  "output": [
    {
      "type": "function_call",
      "call_id": "call_9f2a",
      "name": "get_weather",
      "arguments": "{\"location\":\"Tokyo, Japan\",\"units\":\"metric\"}"
    }
  ]
}
```

## Sending the Tool Result Back

```javascript
const followUp = await fetch("https://api.openai.com/v1/responses", {
  method: "POST",
  headers: { "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "gpt-4.1",
    previous_response_id: response.id,
    input: [
      {
        type: "function_call_output",
        call_id: "call_9f2a",
        output: JSON.stringify({ temperature: 26, condition: "Clear" })
      }
    ]
  })
});
```

## Structured Outputs (final answer schema)

```json
{
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "weather_summary",
      "strict": true,
      "schema": {
        "type": "object",
        "properties": {
          "city": { "type": "string" },
          "temperature_c": { "type": "number" },
          "advice": { "type": "string" }
        },
        "required": ["city", "temperature_c", "advice"],
        "additionalProperties": false
      }
    }
  }
}
```

## Streaming

Set `stream: true`. Watch for `response.function_call_arguments.delta` and `.done` events, buffering per `call_id` before parsing.

## Parallel Tool Calls

Enabled by default; multiple `function_call` items may appear in one `output` array. Disable with `parallel_tool_calls: false` when calls have ordering-sensitive side effects.

## Error Handling

- If arguments fail JSON Schema validation on your end (defense-in-depth even with `strict: true`), return a `function_call_output` with an error payload rather than throwing — this lets the model self-correct.
- Handle `incomplete` / `max_output_tokens` truncation on the `output` array before assuming a `function_call` is complete.

## Best Practices

- Prefer `strict: true` for all tool and structured-output schemas — it eliminates most malformed-argument failures.
- Keep `parameters` schemas flat where possible; strict mode requires `additionalProperties: false` and all properties in `required` (use `["string", "null"]` unions to simulate optional fields).
- Use `previous_response_id` to keep multi-turn tool loops stateless on your side.
