# GitHub Tool

## Overview

A tool for interacting with GitHub repositories: searching code/issues, reading files, and creating issues or pull requests. This example covers `search_issues` (read) and `create_issue` (write).

## Architecture

```
User → Model → tool_call: search_issues(repo, query, state)   [read, safe]
             → Model → tool_call: create_issue(repo, title, body, labels)   [write]
                    │
                    ▼
       Scoped GitHub App / PAT with minimum required permissions
       (issues: write, contents: read — no admin, no delete)
```

## JSON Schema — `create_issue`

```json
{
  "type": "object",
  "properties": {
    "repo": { "type": "string", "description": "owner/repo, e.g. 'anthropics/example'" },
    "title": { "type": "string", "maxLength": 256 },
    "body": { "type": "string" },
    "labels": { "type": "array", "items": { "type": "string" } },
    "assignees": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["repo", "title"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "create_issue",
  "description": "Create a new GitHub issue in the specified repository. Repo must be in 'owner/repo' format.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{
  "repo": "acme/backend",
  "title": "Rate limiter drops requests under burst load",
  "body": "Steps to reproduce:\n1. Send 200 req/s for 5s\n2. Observe dropped requests below documented limit",
  "labels": ["bug", "backend"]
}
```

## Output

```json
{
  "issue_number": 482,
  "url": "https://github.com/acme/backend/issues/482",
  "status": "open"
}
```

## Example Request (Claude)

```json
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1024,
  "tools": [
    { "name": "search_issues", "description": "...", "input_schema": "..." },
    { "name": "create_issue", "description": "...", "input_schema": "..." }
  ],
  "messages": [{ "role": "user", "content": "Check if there's already an issue about the rate limiter bug; if not, file one." }]
}
```

## Example Response

```json
{
  "content": [
    { "type": "tool_use", "id": "toolu_gh01", "name": "search_issues", "input": { "repo": "acme/backend", "query": "rate limiter burst", "state": "open" } }
  ],
  "stop_reason": "tool_use"
}
```

## Reference Implementation (Node.js, Octokit)

```javascript
async function createIssue({ repo, title, body, labels = [], assignees = [] }) {
  const [owner, name] = repo.split("/");
  if (!owner || !name) return { error: "invalid_repo_format", repo };

  const { data } = await octokit.rest.issues.create({
    owner, repo: name, title, body, labels, assignees
  });
  return { issue_number: data.number, url: data.html_url, status: data.state };
}
```

## Error Handling

| Error | Response |
|---|---|
| Invalid `owner/repo` format | `{"error": "invalid_repo_format", "repo": "..."}` |
| Repo not found / no access | `{"error": "repo_not_found_or_forbidden"}` |
| Duplicate issue detected upstream | Return existing issue via `search_issues` result, let model decide |
| Rate limited by GitHub API | `{"error": "rate_limited", "retry_after_seconds": ...}` (from `X-RateLimit-Reset` header) |

## Best Practices

- Scope the GitHub App/token to only the repos and permissions the tool actually needs (issues + contents read, not full `repo` admin scope).
- Always search before creating to avoid duplicate issues — encourage this in the tool description or enforce it in your orchestration logic.
- Treat repository content read via tools (README, issue bodies) as untrusted text — a malicious issue body could contain prompt-injection instructions; never let tool-read content silently trigger a write action (e.g. `create_issue`, `merge_pr`) without confirmation.
- For PR-creation tools, require explicit user confirmation before pushing branches or opening PRs, per the [Security](../README.md#11-security) guidance on irreversible/side-effecting actions.
