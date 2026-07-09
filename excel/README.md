# Excel Tool

## Overview

A tool for reading, writing, and computing over spreadsheet data (e.g. via `openpyxl` on `.xlsx` files, or the Microsoft Graph Excel API for cloud-hosted workbooks). This example covers a `read_range` tool and a `write_range` tool.

## Architecture

```
User → Model → tool_call: read_range(sheet, range)
             → Executor opens workbook, reads cell values/formulas
             → Returns 2D array of values

User → Model → tool_call: write_range(sheet, range, values)
             → Executor validates bounds, writes cells, saves workbook
```

## JSON Schema — `write_range`

```json
{
  "type": "object",
  "properties": {
    "sheet_name": { "type": "string" },
    "range": { "type": "string", "description": "A1-style range, e.g. 'B2:D5'" },
    "values": {
      "type": "array",
      "items": { "type": "array", "items": { "type": ["string", "number", "boolean", "null"] } },
      "description": "2D array of row values matching the range dimensions"
    }
  },
  "required": ["sheet_name", "range", "values"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "write_range",
  "description": "Write values into a cell range on a named sheet of the active workbook. Overwrites existing values in that range.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{
  "sheet_name": "Q3 Budget",
  "range": "B2:C4",
  "values": [
    ["Marketing", 12000],
    ["Engineering", 45000],
    ["Sales", 18000]
  ]
}
```

## Output

```json
{
  "sheet_name": "Q3 Budget",
  "range": "B2:C4",
  "cells_written": 6,
  "status": "saved"
}
```

## Example Request (OpenAI)

```json
{
  "model": "gpt-4.1",
  "input": [{ "role": "user", "content": "Put the department budgets into the Q3 Budget sheet starting at B2." }],
  "tools": [{ "type": "function", "name": "write_range", "description": "...", "parameters": "..." }]
}
```

## Reference Implementation (Python, openpyxl)

```python
from openpyxl import load_workbook
from openpyxl.utils.cell import range_boundaries

def write_range(workbook_path, sheet_name, range_str, values):
    wb = load_workbook(workbook_path)
    if sheet_name not in wb.sheetnames:
        return {"error": "sheet_not_found", "sheet_name": sheet_name}

    ws = wb[sheet_name]
    min_col, min_row, max_col, max_row = range_boundaries(range_str)
    expected_rows, expected_cols = max_row - min_row + 1, max_col - min_col + 1

    if len(values) != expected_rows or any(len(r) != expected_cols for r in values):
        return {"error": "dimension_mismatch",
                "expected": f"{expected_rows}x{expected_cols}",
                "got": f"{len(values)}x{len(values[0]) if values else 0}"}

    for r_offset, row in enumerate(values):
        for c_offset, val in enumerate(row):
            ws.cell(row=min_row + r_offset, column=min_col + c_offset, value=val)

    wb.save(workbook_path)
    return {"sheet_name": sheet_name, "range": range_str, "cells_written": expected_rows * expected_cols, "status": "saved"}
```

## Error Handling

| Error | Response |
|---|---|
| Sheet not found | `{"error": "sheet_not_found", "sheet_name": "..."}` |
| Range dimension mismatch | `{"error": "dimension_mismatch", "expected": "...", "got": "..."}` |
| Invalid A1 range syntax | `{"error": "invalid_range", "range": "..."}` |
| File locked / open elsewhere | `{"error": "file_locked"}` |

## Best Practices

- Validate range dimensions against the supplied `values` array **before** writing any cell — partial writes on error leave the workbook in an inconsistent state.
- For formula cells, decide explicitly whether the tool should read the formula string or the computed value (`data_only=True` in openpyxl) and document this clearly in the tool description.
- Keep a versioned backup or use a transactional save pattern for write operations on shared workbooks.
- For cloud-hosted Excel (Microsoft Graph), prefer the native range-patch API over reconstructing the whole sheet, for both performance and to avoid clobbering concurrent edits.
