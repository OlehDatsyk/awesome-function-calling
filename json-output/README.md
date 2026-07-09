# JSON Output

## Overview

"JSON mode" / "JSON output" refers to constraining a model's raw response text to be syntactically valid JSON, without necessarily enforcing a specific schema shape. It is a weaker guarantee than full **Structured Output** (see [`../structured-output/`](../structured-output)), but useful when the exact shape may vary.

## When to Use JSON Output vs. a Tool Call

| Use Case | Recommended Approach |
|---|---|
| Model needs to take an action / call an API | Tool calling (see `../tool-calling/`) |
| Model needs to return data in a known, fixed shape | Structured output (schema-constrained) |
| Model needs to return *some* JSON, shape may vary per request | Plain JSON mode |

## Provider Support

- **OpenAI**: `response_format: { type: "json_object" }` (legacy) or `{ type: "json_schema", strict: true }` (recommended, see `structured-output/`).
- **Claude**: No dedicated JSON mode; prompt for JSON explicitly and/or use a forced tool call as a structuring mechanism (see `claude/README.md`).
- **Gemini**: `generation_config.response_mime_type: "application/json"`, optionally paired with `response_schema`.

## Example — OpenAI JSON Object Mode

```json
{
  "model": "gpt-4.1",
  "input": [
    { "role": "system", "content": "Respond only with a JSON object." },
    { "role": "user", "content": "Extract the name and age from: 'Maria is 29 years old.'" }
  ],
  "response_format": { "type": "json_object" }
}
```

Response:

```json
{ "name": "Maria", "age": 29 }
```

## Validation Is Still Required

Plain JSON mode guarantees *syntactic* validity (it will parse), but not that the keys/types match what your application expects. Always run the parsed object through a JSON Schema validator before use — see [`../structured-output/`](../structured-output) and [`../templates/`](../templates) for validation patterns.

## Error Handling

- Wrap `JSON.parse` / `json.loads` in a try/catch; on failure, either re-prompt the model with the parse error, or fall back to a stricter structured-output mode.
- Strip Markdown code fences (```json ... ```) defensively — some models wrap JSON in fences even when asked not to.

## Best Practices

- Prefer schema-constrained structured output over plain JSON mode whenever the shape is known ahead of time — it removes an entire class of runtime errors.
- Always instruct the model explicitly not to include prose before/after the JSON object if you're not using a native JSON-mode flag.
- Log raw model output on parse failures for debugging and prompt iteration.
