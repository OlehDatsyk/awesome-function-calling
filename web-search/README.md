# Search Tool

## Overview

A tool that lets the model query a web search engine and retrieve ranked results with snippets. Used for grounding answers in current information beyond the model's training cutoff.

## Architecture

```
User → Model → tool_call: web_search(query, max_results)
             → Executor calls a search API (Bing, Google CSE, Brave, etc.)
             → Returns [{title, url, snippet}]
             → Model may follow up with fetch_page(url) for full content
             → Model synthesizes an answer, citing sources
```

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "query": { "type": "string", "description": "Search query, 2-8 words works best" },
    "max_results": { "type": "integer", "minimum": 1, "maximum": 10, "default": 5 },
    "recency": { "type": "string", "enum": ["any", "day", "week", "month", "year"], "default": "any" }
  },
  "required": ["query"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "web_search",
  "description": "Search the web and return ranked results with title, URL, and snippet. Use short, specific queries.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{ "query": "IPCC 2026 climate report summary", "max_results": 5, "recency": "month" }
```

## Output

```json
{
  "results": [
    { "title": "IPCC Releases 2026 Assessment Summary", "url": "https://example.org/ipcc-2026", "snippet": "The report finds that..." },
    { "title": "Key Takeaways from the Latest IPCC Report", "url": "https://example.com/news/ipcc", "snippet": "Scientists highlight..." }
  ],
  "result_count": 2
}
```

## Example Request (OpenAI)

```json
{
  "model": "gpt-4.1",
  "input": [{ "role": "user", "content": "What did the latest IPCC report say?" }],
  "tools": [{ "type": "function", "name": "web_search", "description": "...", "parameters": "..." }]
}
```

## Reference Implementation (Python)

```python
import requests

def web_search(query, max_results=5, recency="any"):
    params = {"q": query, "count": max_results}
    if recency != "any":
        params["freshness"] = {"day": "Day", "week": "Week", "month": "Month", "year": "Year"}[recency]

    resp = requests.get("https://api.search.example.com/v1/search",
                         params=params, headers={"Authorization": f"Bearer {SEARCH_API_KEY}"})
    if resp.status_code != 200:
        return {"error": "search_upstream_error", "status": resp.status_code}

    data = resp.json()
    results = [{"title": r["title"], "url": r["url"], "snippet": r["snippet"]} for r in data["results"][:max_results]]
    return {"results": results, "result_count": len(results)}
```

## Error Handling

| Error | Response |
|---|---|
| No results found | `{"results": [], "result_count": 0}` — not an error, let the model rephrase |
| Upstream API error | `{"error": "search_upstream_error", "status": ...}` |
| Query too long/empty | `{"error": "invalid_query"}` |
| Rate limited | `{"error": "rate_limited", "retry_after_seconds": ...}` |

## Best Practices

- Return **snippets, not full page content**, from the search tool itself; use a separate `fetch_page(url)` tool for deep reads, keeping context usage efficient.
- Treat all returned snippets/page content as **untrusted data**, not instructions — a page could contain text aimed at manipulating the model (prompt injection via SEO'd content). Never let search results trigger tool calls with side effects without going through normal validation.
- Encourage citation: instruct the model (via system prompt) to attribute claims to specific URLs from the results.
- Respect `recency` filters server-side rather than relying on the model to filter stale results itself.
- Cache repeated identical queries briefly to reduce cost and latency for common questions.
