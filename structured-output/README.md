# Structured Output

## Overview

Structured output is schema-constrained generation: the model's response (tool arguments, or the final answer) is guaranteed — or strongly guided, depending on provider — to conform to a specific JSON Schema you supply.

## Architecture

```
Your JSON Schema
      │
      ▼
Provider-specific structured-output config
 (response_format / response_schema / forced tool)
      │
      ▼
Model generates output constrained to schema
      │
      ▼
Your app parses + validates (defense in depth)
      │
      ▼
Downstream code consumes typed data safely
```

## Provider Comparison

| Feature | OpenAI | Claude | Gemini |
|---|---|---|---|
| Mechanism | `response_format: json_schema, strict: true` | Forced single-tool `tool_choice` | `response_schema` + `response_mime_type: application/json` |
| Guarantee level | Strict (schema-conformant by construction) | Strong (schema validated, occasional edge cases) | Strong (subset of JSON Schema) |
| Nested objects | Full support | Full support | Partial (avoid deep `oneOf`/`anyOf`) |
| Optional fields | Simulate via nullable unions | Native `required` support | Native `required` support |

## Example Schema

```json
{
  "type": "object",
  "properties": {
    "invoice_number": { "type": "string" },
    "total_amount": { "type": "number" },
    "line_items": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "description": { "type": "string" },
          "quantity": { "type": "integer" },
          "unit_price": { "type": "number" }
        },
        "required": ["description", "quantity", "unit_price"],
        "additionalProperties": false
      }
    }
  },
  "required": ["invoice_number", "total_amount", "line_items"],
  "additionalProperties": false
}
```

## Example Request (OpenAI)

```json
{
  "model": "gpt-4.1",
  "input": [{ "role": "user", "content": "Extract invoice data from this text: ..." }],
  "response_format": {
    "type": "json_schema",
    "json_schema": { "name": "invoice", "strict": true, "schema": { "...": "as above" } }
  }
}
```

## Example Response

```json
{
  "invoice_number": "INV-2026-0042",
  "total_amount": 1284.50,
  "line_items": [
    { "description": "Consulting hours", "quantity": 12, "unit_price": 95.0 },
    { "description": "Software license", "quantity": 1, "unit_price": 144.5 }
  ]
}
```

## Error Handling

- Even with `strict: true`, run the response through your JSON Schema validator — treat provider guarantees as strong defaults, not a substitute for your own validation layer.
- Handle truncation: if `max_tokens` is hit mid-object, the response may be syntactically incomplete even in strict mode — check `finish_reason` / `stop_reason` before parsing.

## Best Practices

- Design schemas top-down from what your downstream code needs, not bottom-up from what's "easy" for the model — clarity for consumers matters more than generation convenience.
- Keep enums closed and specific (`"status": {"enum": ["pending","paid","overdue"]}`) rather than open strings, wherever the domain allows it.
- Version schemas alongside your application code; treat them as an API contract.
- Use structured output for extraction/classification tasks; use tool calling for anything that triggers a real side effect.
