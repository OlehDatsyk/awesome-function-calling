# Standard Error Handling Pattern

Every tool in this repository returns errors in a consistent structured shape rather than throwing raw exceptions or returning unstructured strings. This lets the calling model reliably parse and react to failures (retry, ask for clarification, or apologize to the user).

## Standard Shape

```json
{
  "error": "machine_readable_error_code",
  "message": "Short, human-readable explanation",
  "retry_after_seconds": 30
}
```

- `error` — a stable, machine-readable snake_case code. Never change this string without a version bump to the tool contract.
- `message` — a short explanation suitable for the model to relay to the user or reason about.
- Additional fields as needed per error type (e.g. `retry_after_seconds` for rate limits, `field` for validation errors).

## Validation vs. Execution Errors

| Type | Example | Typical model behavior |
|---|---|---|
| Validation error | Missing required field, invalid enum value | Self-correct and retry with fixed arguments |
| Execution error | Upstream API down, resource not found | Inform the user, possibly suggest an alternative |
| Permission/auth error | Expired token, forbidden resource | Surface to user; do not retry silently |
| Confirmation-required | Side-effecting action awaiting explicit user approval | Pause and ask the user, don't proceed automatically |

## Reference Implementation (Python decorator)

```python
import functools
from jsonschema import validate, ValidationError

def tool_handler(schema):
    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(args):
            try:
                validate(instance=args, schema=schema)
            except ValidationError as e:
                return {"error": "validation_error", "message": str(e.message)}
            try:
                return fn(**args)
            except TimeoutError:
                return {"error": "upstream_timeout", "message": "The upstream service timed out."}
            except PermissionError:
                return {"error": "permission_denied", "message": "Insufficient permissions for this action."}
            except Exception as e:
                return {"error": "internal_error", "message": str(e)}
        return wrapper
    return decorator
```

## Best Practices

- Never let an unhandled exception propagate out of a tool executor and crash the whole agent loop — always catch and convert to a structured error result.
- Always return a result for *every* tool call the model made in a turn, even on failure — a missing result for a `tool_use_id`/`call_id` will break the conversation state on most providers.
- Keep error codes stable across versions; add new codes rather than repurposing old ones.
