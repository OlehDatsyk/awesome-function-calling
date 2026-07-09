# Calendar Tool

## Overview

A tool for reading and creating calendar events (e.g. against Google Calendar / Microsoft Graph). This example splits read (`list_events`) and write (`create_event`) into two distinct tools, since they have very different risk profiles.

## Architecture

```
User → Model → tool_call: list_events(start, end)      [read, safe to auto-execute]
             → tool_call: create_event(...)             [write, side-effecting]
                    │
                    ▼
       Application requires explicit user confirmation
       before actually creating the event (see Security)
```

## JSON Schema — `create_event`

```json
{
  "type": "object",
  "properties": {
    "title": { "type": "string", "description": "Event title" },
    "start_time": { "type": "string", "format": "date-time", "description": "ISO 8601, e.g. 2026-07-15T14:00:00-04:00" },
    "end_time": { "type": "string", "format": "date-time" },
    "attendees": {
      "type": "array",
      "items": { "type": "string", "format": "email" },
      "description": "Email addresses of attendees to invite"
    },
    "location": { "type": "string" },
    "description": { "type": "string" }
  },
  "required": ["title", "start_time", "end_time"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "create_event",
  "description": "Create a calendar event. Requires ISO 8601 timestamps with timezone offset. Does not send invites unless attendees are specified.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{
  "title": "Q3 Planning Sync",
  "start_time": "2026-07-15T14:00:00-04:00",
  "end_time": "2026-07-15T15:00:00-04:00",
  "attendees": ["priya@example.com", "sam@example.com"],
  "location": "Zoom"
}
```

## Output

```json
{
  "event_id": "evt_8f21ac",
  "status": "confirmed",
  "html_link": "https://calendar.example.com/event?eid=8f21ac"
}
```

## Example Request (OpenAI Responses API)

```json
{
  "model": "gpt-4.1",
  "input": [{ "role": "user", "content": "Schedule a 30-min sync with Priya and Sam next Wednesday at 2pm ET." }],
  "tools": [
    { "type": "function", "name": "list_events", "description": "...", "parameters": "..." },
    { "type": "function", "name": "create_event", "description": "...", "parameters": "..." }
  ]
}
```

## Example Response

```json
{
  "output": [
    {
      "type": "function_call",
      "call_id": "call_cal01",
      "name": "create_event",
      "arguments": "{\"title\":\"Sync with Priya and Sam\",\"start_time\":\"2026-07-15T14:00:00-04:00\",\"end_time\":\"2026-07-15T14:30:00-04:00\",\"attendees\":[\"priya@example.com\",\"sam@example.com\"]}"
    }
  ]
}
```

## Reference Implementation (Node.js, Google Calendar)

```javascript
async function createEvent({ title, start_time, end_time, attendees = [], location, description }) {
  const event = {
    summary: title,
    location,
    description,
    start: { dateTime: start_time },
    end: { dateTime: end_time },
    attendees: attendees.map(email => ({ email }))
  };
  const res = await calendarClient.events.insert({
    calendarId: "primary",
    requestBody: event,
    sendUpdates: attendees.length ? "all" : "none"
  });
  return { event_id: res.data.id, status: res.data.status, html_link: res.data.htmlLink };
}
```

## Error Handling

| Error | Response |
|---|---|
| End time before start time | `{"error": "invalid_time_range"}` — reject before hitting the API |
| Conflicting event on calendar | `{"error": "conflict", "conflicting_event_id": "..."}` — let model propose alternatives |
| Attendee email invalid | `{"error": "invalid_attendee", "email": "..."}` |
| Auth/token expired | `{"error": "auth_required"}` — surface to user, do not retry silently |

## Best Practices

- **Split read and write tools.** `list_events` can be auto-executed; `create_event` (and especially `delete_event`) should require explicit user confirmation in your application layer before the real API call fires — see [Security](../README.md#11-security).
- Always require explicit timezone offsets in timestamps; never assume a default timezone silently.
- For `create_event`, consider a two-step "propose then confirm" UX: have the model call a `preview_event` tool first, show the user, then call `create_event` only after confirmation.
- Validate that `attendees` don't silently exceed platform limits (e.g. Google Calendar caps attendees per event).
