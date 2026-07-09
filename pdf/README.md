# PDF Tool

## Overview

A tool for extracting text, tables, and metadata from PDF documents, and optionally generating new PDFs from structured content. This example focuses on `extract_pdf_text`, the most common use case for grounding a model in document content.

## Architecture

```
User → Model → tool_call: extract_pdf_text(file_id, page_range)
             → Executor loads the PDF (from an uploaded file store or URL)
             → Extracts text per page (OCR fallback for scanned pages)
             → Returns text keyed by page number, capped in size
```

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "file_id": { "type": "string", "description": "Reference ID of a previously uploaded PDF" },
    "page_range": { "type": "string", "description": "e.g. '1-5' or '3'. Omit for the whole document (capped at 50 pages)." },
    "include_tables": { "type": "boolean", "default": false }
  },
  "required": ["file_id"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "extract_pdf_text",
  "description": "Extract text (and optionally detected tables) from a previously uploaded PDF file, by page range.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{ "file_id": "file_8a21", "page_range": "1-3", "include_tables": true }
```

## Output

```json
{
  "file_id": "file_8a21",
  "pages": [
    { "page": 1, "text": "Annual Report 2026\n\nExecutive Summary...", "tables": [] },
    { "page": 2, "text": "Financial Highlights...", "tables": [{ "rows": [["Q1", "Q2", "Q3"], ["120", "134", "148"]] }] }
  ],
  "page_count_total": 42,
  "truncated": false
}
```

## Example Request (Claude)

```json
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1024,
  "tools": [{ "name": "extract_pdf_text", "description": "...", "input_schema": "..." }],
  "messages": [{ "role": "user", "content": "What were the Q2 financial highlights in this report? (file_8a21)" }]
}
```

## Reference Implementation (Python, pypdf + OCR fallback)

```python
from pypdf import PdfReader

def extract_pdf_text(file_id, page_range=None, include_tables=False):
    path = resolve_file_path(file_id)
    if path is None:
        return {"error": "file_not_found", "file_id": file_id}

    reader = PdfReader(path)
    total_pages = len(reader.pages)
    indices = parse_page_range(page_range, total_pages, cap=50)

    pages = []
    for i in indices:
        text = reader.pages[i].extract_text() or ""
        if not text.strip():
            text = ocr_page(path, i)  # fallback for scanned/image-only pages
        entry = {"page": i + 1, "text": text}
        if include_tables:
            entry["tables"] = extract_tables_from_page(path, i)
        pages.append(entry)

    return {
        "file_id": file_id,
        "pages": pages,
        "page_count_total": total_pages,
        "truncated": len(indices) < total_pages and page_range is None
    }
```

## Error Handling

| Error | Response |
|---|---|
| File not found | `{"error": "file_not_found", "file_id": "..."}` |
| Encrypted/password-protected PDF | `{"error": "encrypted_pdf"}` |
| Page range out of bounds | `{"error": "invalid_page_range", "page_count_total": ...}` |
| Corrupt PDF | `{"error": "corrupt_pdf"}` |

## Best Practices

- Cap page ranges server-side (e.g. 50 pages per call) to keep tool results within a reasonable context budget; encourage iterative reads for large documents.
- Fall back to OCR automatically for pages with no extractable text layer (scanned documents) rather than returning empty strings silently.
- Separate table extraction from plain text extraction as an opt-in flag (`include_tables`) since table detection is more expensive and error-prone.
- Return page numbers alongside text so the model can cite specific pages in its answer.
