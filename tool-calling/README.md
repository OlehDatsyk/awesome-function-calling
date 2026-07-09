# Tool Calling — Architecture & Lifecycle

## Overview

This document describes the provider-agnostic architecture used by every tool example in this repository, and the general lifecycle of a tool-calling turn.

## Architecture

```
┌─────────────┐     tool definitions      ┌──────────────┐
│ Your App    │ ─────────────────────────▶│  LLM Provider│
│ (Orchestrator)                           │ (OpenAI/     │
│             │◀───────────────────────── │  Claude/     │
└─────────────┘   tool_use / function_call │  Gemini)     │
      │                                     └──────────────┘
      │ executes
      ▼
┌─────────────┐
│ Real Tool   │  (Weather API, DB, filesystem, email service, ...)
│ Implementation
└─────────────┘
      │
      ▼
  result / error
      │
      ▼
  sent back to model as tool_result / function_call_output / functionResponse
```

## The Lifecycle

1. **Define** — declare tools with name, description, and JSON Schema.
2. **Request** — send the user message + tool definitions to the model.
3. **Decide** — the model decides whether to respond directly or call one or more tools.
4. **Execute** — your application runs the real function against the validated arguments.
5. **Return** — the result (or a structured error) is sent back to the model, tagged with the originating call ID.
6. **Continue or Conclude** — the model either calls another tool (agentic loop) or produces a final answer.

## Single Tool Call

```
User → Model → [tool_call: get_weather] → Executor → [result] → Model → Final answer
```

## Multi-Tool / Agentic Loop

```
User → Model → [tool_call: search_flights] → Executor → [result]
             → Model → [tool_call: check_calendar] → Executor → [result]
             → Model → [tool_call: send_email] → Executor → [result]
             → Model → Final answer
```

Cap agentic loops with a **max-turns** limit (typically 5–15 depending on task complexity) to avoid runaway cost/latency.

## Generic Tool Executor (pseudocode)

```python
def run_agent(user_message, tools, max_turns=10):
    messages = [{"role": "user", "content": user_message}]
    for _ in range(max_turns):
        response = call_model(messages, tools)
        if response.stop_reason != "tool_use":
            return response.final_text

        tool_results = []
        for call in response.tool_calls:  # may run concurrently
            try:
                validate(call.arguments, tools[call.name].schema)
                result = execute(call.name, call.arguments)
                tool_results.append(ok_result(call.id, result))
            except Exception as e:
                tool_results.append(error_result(call.id, str(e)))

        messages.append(response.as_message())
        messages.append(tool_results_as_message(tool_results))

    return "Max turns reached without a final answer."
```

## Error Handling

- Distinguish **validation errors** (bad arguments — usually a model mistake, self-correctable) from **execution errors** (the tool itself failed — e.g. API timeout, not found).
- Always return *something* for every tool call the model made in a turn — never silently drop a call, or the conversation state becomes inconsistent.
- Use a consistent structured error shape across all tools (see [`../templates/error-handling-template.md`](../templates/error-handling-template.md)).

## Best Practices

- One tool = one clear responsibility. Avoid "god tools" with many unrelated modes.
- Idempotent tools (read-only lookups) can be retried freely; side-effecting tools (send email, delete file) should not be retried automatically without deduplication logic.
- Log the full request/response/tool-call trace for every agentic session — essential for debugging and for security auditing.
- Treat tool descriptions as living documentation — iterate on them based on observed tool-selection mistakes in production.
