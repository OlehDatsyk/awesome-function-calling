# Email Tool

## Overview

A tool for reading and sending email (e.g. via Gmail API / Microsoft Graph / SMTP). Sending email is an **irreversible, side-effecting action** and must always require explicit user confirmation — see Security notes below.

## Architecture

```
User → Model → tool_call: search_inbox(query)        [read]
             → tool_call: draft_email(to, subject, body)  [safe: creates a draft, no send]
             → [explicit user confirmation in UI]
             → tool_call: send_email(draft_id)        [side-effecting, irreversible]
```

Splitting `draft_email` from `send_email` gives you a natural human-in-the-loop checkpoint.

## JSON Schema — `send_email`

```json
{
  "type": "object",
  "properties": {
    "to": { "type": "array", "items": { "type": "string", "format": "email" }, "minItems": 1 },
    "cc": { "type": "array", "items": { "type": "string", "format": "email" } },
    "subject": { "type": "string", "maxLength": 200 },
    "body": { "type": "string", "description": "Plain text or simple HTML body" },
    "draft_id": { "type": "string", "description": "If sending a previously created draft, its ID" }
  },
  "required": ["to", "subject", "body"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "send_email",
  "description": "Send an email. This action is irreversible and will be delivered immediately — only call after the user has explicitly confirmed the content.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{
  "to": ["team@example.com"],
  "subject": "Weekly Status Update",
  "body": "Hi team,\n\nHere is this week's summary...\n\nBest,\nAlex"
}
```

## Output

```json
{
  "message_id": "18f2ac9e7b3d4a11",
  "status": "sent",
  "sent_at": "2026-07-09T10:32:00Z"
}
```

## Example Request (Claude, forced confirmation flow)

```json
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1024,
  "tools": [
    { "name": "draft_email", "description": "...", "input_schema": "..." },
    { "name": "send_email", "description": "...", "input_schema": "..." }
  ],
  "messages": [{ "role": "user", "content": "Draft a status update email to the team and let me review it before sending." }]
}
```

## Example Response

```json
{
  "content": [
    {
      "type": "tool_use",
      "id": "toolu_email01",
      "name": "draft_email",
      "input": { "to": ["team@example.com"], "subject": "Weekly Status Update", "body": "Hi team,\n\n..." }
    }
  ],
  "stop_reason": "tool_use"
}
```

## Reference Implementation (Python, Gmail API)

```python
import base64
from email.mime.text import MIMEText

def send_email(to, subject, body, cc=None, draft_id=None):
    if draft_id:
        result = gmail.users().drafts().send(userId="me", body={"id": draft_id}).execute()
    else:
        message = MIMEText(body)
        message["to"] = ", ".join(to)
        message["subject"] = subject
        if cc:
            message["cc"] = ", ".join(cc)
        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
        result = gmail.users().messages().send(userId="me", body={"raw": raw}).execute()

    return {"message_id": result["id"], "status": "sent"}
```

## Error Handling

| Error | Response |
|---|---|
| Invalid recipient address | `{"error": "invalid_recipient", "email": "..."}` |
| Attachment too large | `{"error": "attachment_too_large", "max_bytes": 25000000}` |
| Auth/token expired | `{"error": "auth_required"}` |
| Send quota exceeded | `{"error": "quota_exceeded", "retry_after_seconds": 3600}` |

## Best Practices

- **Never call `send_email` directly from a model decision alone.** Require an explicit UI confirmation step between draft and send (see [Security](../README.md#11-security) — "Human-in-the-loop for irreversible actions").
- Treat email *body content read by other tools* (e.g. `search_inbox` results) as untrusted — a malicious email could contain prompt-injection text aimed at the model. Never let inbound email content trigger a `send_email` call without confirmation.
- Cap recipient counts and rate-limit sends per user/session to prevent spam-like abuse of the tool.
- Log every send (to, subject, timestamp, initiating user) for audit purposes.
