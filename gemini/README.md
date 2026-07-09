# Gemini — Function Calling (Google GenAI API)

## Overview

Gemini models support function calling via `generateContent` (or `streamGenerateContent`). Tools are declared as `FunctionDeclaration` objects grouped under a `Tool`, passed in the `tools` field of the request.

## Core Concepts

- `function_calling_config.mode`: `AUTO` (default), `ANY` (force a tool call, optionally restricted via `allowed_function_names`), or `NONE`.
- The model returns a `functionCall` part inside a candidate's `content`; you execute it and reply with a `functionResponse` part.
- Gemini natively supports **compositional function calling** — chaining dependent calls across multiple turns — and **parallel function calling** for independent calls in one turn.
- `response_schema` + `response_mime_type: "application/json"` provides structured output for the model's final natural-language answer.

## Tool Definition

```json
{
  "function_declarations": [
    {
      "name": "get_weather",
      "description": "Get the current weather for a given city.",
      "parameters": {
        "type": "object",
        "properties": {
          "location": { "type": "string", "description": "City and country, e.g. 'Berlin, Germany'" },
          "units": { "type": "string", "enum": ["metric", "imperial"] }
        },
        "required": ["location"]
      }
    }
  ]
}
```

## Example Request

```javascript
const response = await fetch(
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${process.env.GEMINI_API_KEY}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: "What's the weather in Tokyo?" }] }],
      tools: [weatherToolDeclaration],
      tool_config: { function_calling_config: { mode: "AUTO" } }
    })
  }
);
```

## Example Response (model requests a tool call)

```json
{
  "candidates": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "functionCall": {
              "name": "get_weather",
              "args": { "location": "Tokyo, Japan", "units": "metric" }
            }
          }
        ]
      }
    }
  ]
}
```

## Sending the Tool Result Back

```javascript
const followUp = await fetch(
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${process.env.GEMINI_API_KEY}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        { role: "user", parts: [{ text: "What's the weather in Tokyo?" }] },
        { role: "model", parts: [{ functionCall: { name: "get_weather", args: { location: "Tokyo, Japan", units: "metric" } } }] },
        {
          role: "user",
          parts: [{
            functionResponse: {
              name: "get_weather",
              response: { temperature: 26, condition: "Clear" }
            }
          }]
        }
      ],
      tools: [weatherToolDeclaration]
    })
  }
);
```

## Structured Output (final answer schema)

```json
{
  "generation_config": {
    "response_mime_type": "application/json",
    "response_schema": {
      "type": "object",
      "properties": {
        "city": { "type": "string" },
        "temperature_c": { "type": "number" },
        "advice": { "type": "string" }
      },
      "required": ["city", "temperature_c", "advice"]
    }
  }
}
```

## Streaming

Use `streamGenerateContent`. Function calls typically arrive as a complete `functionCall` part in one streamed chunk rather than incremental JSON token deltas — buffer by candidate index and parts array.

## Parallel & Compositional Calling

Gemini can return multiple `functionCall` parts in one turn (parallel), or request a new call after receiving a previous `functionResponse` in the same conversation (compositional/sequential). Design your executor to handle both without assuming a fixed number of round trips.

## Error Handling

- Return a `functionResponse` with an `error` field inside `response` on failure (e.g. `{"response": {"error": "city_not_found"}}`) rather than omitting the response — Gemini expects one `functionResponse` per `functionCall`.
- Validate `args` against your schema before executing; Gemini's schema subset is more constrained than full JSON Schema (limited `oneOf`/`anyOf` support), so keep parameter schemas relatively flat.

## Best Practices

- Use `ANY` mode with `allowed_function_names` when you need a guaranteed, constrained tool call (e.g. classification-style tasks).
- Keep nested schema depth shallow — Gemini's function-calling schema support is a constrained subset of full JSON Schema.
- For multi-step agentic tasks, track conversation state yourself and resend the full `contents` array each turn, since Gemini does not have a server-side "previous response" reference like OpenAI's Responses API.
