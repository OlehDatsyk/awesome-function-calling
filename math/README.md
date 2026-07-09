# Math Tool

## Overview

A tool that offloads precise numerical computation to a real evaluator instead of relying on the model's own arithmetic, which is unreliable for large numbers, exact precision, or multi-step algebra. This example uses a sandboxed expression evaluator, not `eval()`.

## Architecture

```
User → Model → tool_call: calculate(expression)
             → Executor parses the expression with a safe math grammar
               (no arbitrary code execution — see Security notes)
             → Returns the computed result with the requested precision
```

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "expression": {
      "type": "string",
      "description": "A mathematical expression, e.g. '(1500 * 1.045^10) - 1500'. Supports +,-,*,/,^,sqrt,sin,cos,log,pi,e and parentheses."
    },
    "precision": { "type": "integer", "minimum": 0, "maximum": 15, "default": 6 }
  },
  "required": ["expression"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "calculate",
  "description": "Evaluate a mathematical expression with exact precision. Use this for any arithmetic beyond trivial mental math, especially compound calculations, exponents, and financial math.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{ "expression": "(1500 * 1.045^10) - 1500", "precision": 2 }
```

## Output

```json
{ "expression": "(1500 * 1.045^10) - 1500", "result": 830.53, "precision": 2 }
```

## Example Request (Gemini)

```json
{
  "contents": [{ "role": "user", "parts": [{ "text": "If I invest $1500 at 4.5% annual compound interest, how much interest do I earn over 10 years?" }] }],
  "tools": [{ "function_declarations": [{ "name": "calculate", "description": "...", "parameters": "..." }] }]
}
```

## Reference Implementation (Python, `asteval` — sandboxed, no arbitrary exec)

```python
from asteval import Interpreter

def calculate(expression: str, precision: int = 6):
    aeval = Interpreter(minimal=True)  # no imports, no file/network access, no exec
    aeval.symtable.update({"pi": 3.141592653589793, "e": 2.718281828459045})

    result = aeval(expression)
    if aeval.error:
        return {"error": "invalid_expression", "message": str(aeval.error[0].get_error())}
    if result is None or isinstance(result, (list, dict, str)):
        return {"error": "non_numeric_result"}

    return {"expression": expression, "result": round(result, precision), "precision": precision}
```

## Error Handling

| Error | Response |
|---|---|
| Syntax error in expression | `{"error": "invalid_expression", "message": "..."}` |
| Division by zero | `{"error": "division_by_zero"}` |
| Result is non-numeric (e.g. complex/undefined) | `{"error": "non_numeric_result"}` |
| Expression too long/complex (DoS guard) | `{"error": "expression_too_complex"}` |

## Best Practices

- **Never use `eval()` or a general-purpose scripting sandbox for this tool.** Use a restricted math-expression grammar/library (e.g. `asteval` in minimal mode, or a dedicated expression parser) with no access to imports, file I/O, or network calls.
- Cap expression length and nesting depth to prevent pathological inputs from causing excessive CPU use.
- Round to a sane default precision (e.g. 6 decimal places) unless the user/task requires more, to avoid noisy floating-point artifacts in the model's final answer.
- For symbolic math (solving equations, calculus), use a dedicated tool (e.g. backed by `sympy`) rather than overloading this numeric-evaluation tool.
