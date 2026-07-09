# Translation Tool

## Overview

A tool that delegates text translation to a dedicated machine-translation service/model, useful when you need consistent, auditable translations (e.g. for a product with a certified translation pipeline) rather than relying on the orchestrating model's own multilingual generation.

## Architecture

```
User → Model → tool_call: translate(text, target_language, source_language)
             → Executor calls a translation API (e.g. DeepL, Google Translate)
             → Returns translated text + detected source language + confidence
```

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "text": { "type": "string", "maxLength": 5000 },
    "target_language": { "type": "string", "description": "ISO 639-1 code, e.g. 'fr', 'ja', 'es'" },
    "source_language": { "type": "string", "description": "ISO 639-1 code. Omit to auto-detect." },
    "formality": { "type": "string", "enum": ["default", "formal", "informal"], "default": "default" }
  },
  "required": ["text", "target_language"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "translate",
  "description": "Translate text into a target language using a dedicated translation engine. Preserves formatting and does not summarize or alter meaning.",
  "input_schema": { "...": "see above" }
}
```

## Input

```json
{ "text": "Please confirm your order by Friday.", "target_language": "ja", "formality": "formal" }
```

## Output

```json
{
  "translated_text": "金曜日までにご注文の確認をお願いいたします。",
  "detected_source_language": "en",
  "target_language": "ja"
}
```

## Example Request (OpenAI)

```json
{
  "model": "gpt-4.1",
  "input": [{ "role": "user", "content": "Translate 'Please confirm your order by Friday' into formal Japanese." }],
  "tools": [{ "type": "function", "name": "translate", "description": "...", "parameters": "..." }]
}
```

## Reference Implementation (Python, DeepL-style API)

```python
import requests

SUPPORTED_LANGUAGES = {"en", "fr", "de", "es", "ja", "zh", "pt", "it", "nl", "ko"}

def translate(text, target_language, source_language=None, formality="default"):
    if target_language not in SUPPORTED_LANGUAGES:
        return {"error": "unsupported_language", "language": target_language}
    if len(text) > 5000:
        return {"error": "text_too_long", "max_chars": 5000}

    payload = {"text": [text], "target_lang": target_language.upper()}
    if source_language:
        payload["source_lang"] = source_language.upper()
    if formality != "default":
        payload["formality"] = formality

    resp = requests.post("https://api.translation.example.com/v2/translate",
                          json=payload, headers={"Authorization": f"Bearer {TRANSLATE_API_KEY}"})
    if resp.status_code != 200:
        return {"error": "translation_upstream_error", "status": resp.status_code}

    result = resp.json()["translations"][0]
    return {
        "translated_text": result["text"],
        "detected_source_language": result.get("detected_source_language", source_language),
        "target_language": target_language
    }
```

## Error Handling

| Error | Response |
|---|---|
| Unsupported target language | `{"error": "unsupported_language", "language": "..."}` |
| Text exceeds max length | `{"error": "text_too_long", "max_chars": 5000}` |
| Upstream API error | `{"error": "translation_upstream_error", "status": ...}` |
| Empty/whitespace-only text | `{"error": "empty_text"}` |

## Best Practices

- Use ISO 639-1 language codes consistently in both input and output to avoid ambiguity (e.g. `"pt"` vs `"pt-BR"` — decide and document a convention).
- For long documents, chunk text server-side (respecting sentence boundaries) rather than relying on the model to split it, then reassemble in order.
- Preserve placeholders/variables (e.g. `{{user_name}}`) untranslated by using the translation API's glossary/no-translate features where available.
- Cache translations of frequently repeated strings (e.g. UI labels) to reduce cost and ensure consistency across calls.
