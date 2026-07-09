# [Tool Name]

## Overview

One or two sentences: what does this tool do, and is it read-only or side-effecting?

## Architecture

```
User → Model → tool_call: tool_name(args)
             → Executor does X
             → Returns Y
```

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "example_param": { "type": "string", "description": "..." }
  },
  "required": ["example_param"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "tool_name",
  "description": "Clear, specific description written for the model — include units, formats, and constraints.",
  "input_schema": { "...": "see JSON Schema above" }
}
```

## Input

```json
{ "example_param": "value" }
```

## Output

```json
{ "result": "..." }
```

## Example Request

```json
{ "...": "provider-specific request showing this tool declared" }
```

## Example Response

```json
{ "...": "provider-specific response showing the tool_call/function_call" }
```

## Error Handling

| Error | Response |
|---|---|
| ... | `{"error": "...", "message": "..."}` |

## Best Practices

- ...
- ...
