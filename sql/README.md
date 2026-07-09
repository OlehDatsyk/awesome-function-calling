# SQL Tool

## Overview

A tool that lets a model query a relational database. This is one of the highest-risk tools in this repository — untrusted, model-generated SQL running against production data is a direct SQL-injection and data-exfiltration vector. This example uses an **allow-listed, parameterized query pattern** rather than free-form SQL execution.

## Architecture

```
User → Model → tool_call: run_query(table, filters, columns, limit)
             → Executor builds a PARAMETERIZED query from an allow-list
               (never string-concatenates model output into SQL)
             → Read-only DB role (no INSERT/UPDATE/DELETE/DDL grants)
             → Rows returned, capped at max_rows
```

Two design options, in increasing order of risk:

1. **Structured filter tool** (recommended) — the model supplies table/column/operator/value, and your code builds the SQL. No raw SQL ever comes from the model. *(shown below)*
2. **Free-form read-only SQL tool** — the model writes full `SELECT` statements, validated by a SQL parser/allow-list before execution against a read-only replica. Higher flexibility, higher risk — only use with a dedicated SQL sandbox and strict statement-type allow-listing (`SELECT` only, no subqueries into system tables).

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "table": { "type": "string", "enum": ["orders", "customers", "products"] },
    "columns": { "type": "array", "items": { "type": "string" }, "description": "Columns to return; omit for all allow-listed columns" },
    "filters": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "column": { "type": "string" },
          "operator": { "type": "string", "enum": ["=", "!=", ">", "<", ">=", "<=", "LIKE"] },
          "value": { "type": ["string", "number", "boolean"] }
        },
        "required": ["column", "operator", "value"]
      }
    },
    "limit": { "type": "integer", "minimum": 1, "maximum": 500, "default": 100 }
  },
  "required": ["table"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "run_query",
  "description": "Query an allow-listed table with structured filters. Read-only. Returns at most 500 rows.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{
  "table": "orders",
  "columns": ["order_id", "customer_id", "total", "status"],
  "filters": [{ "column": "status", "operator": "=", "value": "overdue" }],
  "limit": 50
}
```

## Output

```json
{
  "rows": [
    { "order_id": "ORD-1042", "customer_id": "C-991", "total": 219.50, "status": "overdue" },
    { "order_id": "ORD-1077", "customer_id": "C-102", "total": 84.00, "status": "overdue" }
  ],
  "row_count": 2,
  "truncated": false
}
```

## Example Request (Gemini)

```json
{
  "contents": [{ "role": "user", "parts": [{ "text": "How many orders are overdue right now?" }] }],
  "tools": [{ "function_declarations": [{ "name": "run_query", "description": "...", "parameters": "..." }] }]
}
```

## Reference Implementation (Python, parameterized — allow-listed columns only)

```python
ALLOWED_TABLES = {
    "orders": {"order_id", "customer_id", "total", "status", "created_at"},
    "customers": {"customer_id", "name", "region"},
    "products": {"sku", "name", "price"},
}

def run_query(table, columns=None, filters=None, limit=100):
    if table not in ALLOWED_TABLES:
        return {"error": "table_not_allowed", "table": table}

    allowed_cols = ALLOWED_TABLES[table]
    columns = columns or list(allowed_cols)
    if not set(columns).issubset(allowed_cols):
        return {"error": "column_not_allowed", "columns": list(set(columns) - allowed_cols)}

    where_clauses, params = [], []
    for f in (filters or []):
        if f["column"] not in allowed_cols:
            return {"error": "column_not_allowed", "column": f["column"]}
        where_clauses.append(f'"{f["column"]}" {f["operator"]} %s')
        params.append(f["value"])

    sql = f'SELECT {", ".join(columns)} FROM "{table}"'
    if where_clauses:
        sql += " WHERE " + " AND ".join(where_clauses)
    sql += " LIMIT %s"
    params.append(min(limit, 500))

    with readonly_db_connection() as conn:
        rows = conn.execute(sql, params).fetchall()
    return {"rows": rows, "row_count": len(rows), "truncated": len(rows) == 500}
```

## Error Handling

| Error | Response |
|---|---|
| Table not in allow-list | `{"error": "table_not_allowed", "table": "..."}` |
| Column not in allow-list | `{"error": "column_not_allowed", "columns": [...]}` |
| Query timeout | `{"error": "query_timeout"}` |
| Result set too large | Truncate to `limit`, set `"truncated": true` |

## Best Practices

- **Never string-concatenate model-supplied values into SQL.** Always use parameterized queries with a real driver-level parameter binding, even for the allow-listed table/column pattern above.
- Run all model-driven queries against a **read-only** database role/replica with no `INSERT`/`UPDATE`/`DELETE`/DDL grants.
- Enforce a hard `LIMIT` server-side regardless of what the model requests.
- Never expose system tables, credentials tables, or PII columns via the allow-list unless explicitly required and access-controlled.
- Log every executed query (with parameters) for audit purposes.
