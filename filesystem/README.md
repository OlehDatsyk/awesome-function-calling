# Filesystem Tool

## Overview

A tool for reading, writing, and listing files within a **sandboxed root directory**. Filesystem access is a high-risk capability (path traversal, arbitrary read/write) and must always be constrained to a jailed root.

## Architecture

```
User → Model → tool_call: read_file(path)
             → Executor resolves path against SANDBOX_ROOT
             → Rejects any resolved path outside SANDBOX_ROOT (path traversal defense)
             → Returns file contents (size-capped)

User → Model → tool_call: write_file(path, content)   [side-effecting]
             → Same sandboxing + explicit confirmation for overwrites
```

## JSON Schema — `read_file`

```json
{
  "type": "object",
  "properties": {
    "path": { "type": "string", "description": "Path relative to the sandbox root, e.g. 'reports/q3.md'. No '..' segments allowed." },
    "max_bytes": { "type": "integer", "minimum": 1, "maximum": 1000000, "default": 100000 }
  },
  "required": ["path"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "read_file",
  "description": "Read a text file relative to the sandboxed working directory. Paths outside the sandbox are rejected.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{ "path": "reports/q3.md", "max_bytes": 50000 }
```

## Output

```json
{
  "path": "reports/q3.md",
  "content": "# Q3 Report\n\n...",
  "size_bytes": 4213,
  "truncated": false
}
```

## Example Request (Gemini)

```json
{
  "contents": [{ "role": "user", "parts": [{ "text": "Summarize reports/q3.md" }] }],
  "tools": [{ "function_declarations": [{ "name": "read_file", "description": "...", "parameters": "..." }] }]
}
```

## Reference Implementation (Python, path-traversal-safe)

```python
import os

SANDBOX_ROOT = os.path.realpath("/var/app/sandbox")

def _resolve_safe(path: str) -> str | None:
    candidate = os.path.realpath(os.path.join(SANDBOX_ROOT, path))
    if os.path.commonpath([candidate, SANDBOX_ROOT]) != SANDBOX_ROOT:
        return None  # path escapes the sandbox
    return candidate

def read_file(path, max_bytes=100_000):
    resolved = _resolve_safe(path)
    if resolved is None:
        return {"error": "path_outside_sandbox", "path": path}
    if not os.path.isfile(resolved):
        return {"error": "file_not_found", "path": path}

    size = os.path.getsize(resolved)
    with open(resolved, "r", errors="replace") as f:
        content = f.read(max_bytes)

    return {"path": path, "content": content, "size_bytes": size, "truncated": size > max_bytes}
```

## Error Handling

| Error | Response |
|---|---|
| Path escapes sandbox (`..`, symlink tricks) | `{"error": "path_outside_sandbox", "path": "..."}` |
| File not found | `{"error": "file_not_found", "path": "..."}` |
| File too large | Truncate at `max_bytes`, set `"truncated": true` |
| Permission denied | `{"error": "permission_denied", "path": "..."}` |
| Binary/non-UTF8 content requested as text | `{"error": "unsupported_file_type", "path": "..."}` |

## Best Practices

- **Always resolve paths against a real, canonicalized sandbox root** (`os.path.realpath`) and verify the resolved path is still inside it — string-prefix checks alone (`path.startswith(root)`) are insufficient and bypassable via symlinks.
- Never expose `write_file` or `delete_file` without a confirmation step for anything outside a scratch/temp directory — see [Security](../README.md#11-security).
- Cap read sizes (`max_bytes`) to avoid flooding the model's context window with huge files; prefer a `list_files` + targeted `read_file` pattern over dumping entire directory trees.
- Run the executing process itself with OS-level restricted permissions (non-root user, read-only mount where possible) as defense in depth beyond the application-level sandbox.
