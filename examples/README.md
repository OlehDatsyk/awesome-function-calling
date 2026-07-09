# Examples — Multi-Tool Orchestration

This folder contains end-to-end examples that combine multiple tools from this repository into realistic agentic workflows.

## Example 1: "Check the weather, then email the team if rain is expected"

Combines [`weather/`](../weather) (read) and [`email/`](../email) (write, requires confirmation).

```
User: "If it's going to rain in Chicago tomorrow, email the field team a heads-up."

1. Model → tool_call: get_weather(location="Chicago, USA", forecast_days=1)
2. Executor → { forecast: [{ day: 1, condition: "Rain", precip_chance: 80 }] }
3. Model → tool_call: draft_email(to=["field-team@example.com"], subject="Rain expected tomorrow", body="...")
4. [App surfaces the draft to the user for confirmation]
5. User confirms → tool_call: send_email(draft_id="...")
6. Model → final answer: "Rain is expected (80% chance) — I've sent a heads-up to the field team."
```

## Example 2: "Summarize this PDF and log a GitHub issue for any bugs mentioned"

Combines [`pdf/`](../pdf) and [`github/`](../github).

```
1. Model → tool_call: extract_pdf_text(file_id="file_8a21")
2. Executor → { pages: [...] }
3. Model reasons over extracted text, identifies bug reports
4. Model → tool_call: search_issues(repo="acme/backend", query="rate limiter") [dedup check]
5. Model → tool_call: create_issue(repo="acme/backend", title="...", body="...")
6. Model → final answer summarizing the PDF and linking the created issue
```

## Example 3: "Pull overdue orders from the DB and put them in a spreadsheet"

Combines [`sql/`](../sql) and [`excel/`](../excel) — a good example of **parallel-safe read followed by a single write**.

```
1. Model → tool_call: run_query(table="orders", filters=[{column:"status",operator:"=",value:"overdue"}])
2. Executor → { rows: [...], row_count: 14 }
3. Model → tool_call: write_range(sheet_name="Overdue Orders", range="A1:D15", values=[...])
4. Model → final answer: "I've listed all 14 overdue orders in the 'Overdue Orders' sheet."
```

## Generic Multi-Tool Executor (Python)

```python
def run_agent(user_message, tools_by_name, model_client, max_turns=8):
    messages = [{"role": "user", "content": user_message}]

    for turn in range(max_turns):
        response = model_client.send(messages, tools=list(tools_by_name.values()))

        if not response.has_tool_calls:
            return response.text  # final answer

        results = []
        for call in response.tool_calls:  # run independent calls concurrently
            tool = tools_by_name.get(call.name)
            if tool is None:
                results.append(error_result(call.id, "unknown_tool"))
                continue
            if tool.requires_confirmation and not call.confirmed:
                return {"pending_confirmation": call}  # surface to user, pause loop
            try:
                validate(call.arguments, tool.schema)
                results.append(ok_result(call.id, tool.execute(call.arguments)))
            except Exception as e:
                results.append(error_result(call.id, str(e)))

        messages += [response.as_message(), results_as_message(results)]

    return "Reached max turns without a final answer."
```

## Key Takeaways

- **Read tools chain freely**; **write tools pause for confirmation** — encode this as a `requires_confirmation` flag per tool, not as ad-hoc logic scattered through your code.
- Multi-tool agents should always have a **max-turns cap** and a graceful fallback message.
- Treat every tool result the same way regardless of which tool produced it: validate before use, never treat it as trusted instructions.
