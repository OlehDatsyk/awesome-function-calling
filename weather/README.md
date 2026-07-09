# Weather Tool

## Overview

A read-only tool that retrieves current weather conditions or a short forecast for a given location. This is the canonical "hello world" of function calling: no side effects, simple schema, easy to test.

## Architecture

```
User → Model → tool_call: get_weather(location, units)
             → Executor calls a weather API (e.g. Open-Meteo, OpenWeatherMap)
             → Executor returns { temperature, condition, humidity }
             → Model produces natural-language answer
```

Because this tool is read-only and idempotent, it is safe to retry, cache, and call in parallel for multiple locations.

## JSON Schema

```json
{
  "type": "object",
  "properties": {
    "location": {
      "type": "string",
      "description": "City and country, e.g. 'Paris, France'. Do not pass coordinates."
    },
    "units": {
      "type": "string",
      "enum": ["metric", "imperial"],
      "description": "metric = Celsius/km/h, imperial = Fahrenheit/mph. Defaults to metric."
    },
    "forecast_days": {
      "type": "integer",
      "minimum": 0,
      "maximum": 7,
      "description": "0 = current conditions only. 1-7 = number of forecast days to include."
    }
  },
  "required": ["location"],
  "additionalProperties": false
}
```

## Tool Definition

```json
{
  "name": "get_weather",
  "description": "Get current weather conditions and an optional multi-day forecast for a city. Returns temperature, condition, and humidity.",
  "input_schema": { "...": "see JSON Schema above" }
}
```

## Input

```json
{ "location": "Tokyo, Japan", "units": "metric", "forecast_days": 0 }
```

## Output

```json
{
  "location": "Tokyo, Japan",
  "temperature": 26.4,
  "condition": "Clear",
  "humidity": 58,
  "units": "metric",
  "observed_at": "2026-07-09T09:00:00+09:00"
}
```

## Example Request (Claude)

```json
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1024,
  "tools": [{ "name": "get_weather", "description": "...", "input_schema": "..." }],
  "messages": [{ "role": "user", "content": "Should I bring an umbrella in Tokyo today?" }]
}
```

## Example Response

```json
{
  "content": [
    { "type": "text", "text": "Let me check the weather in Tokyo." },
    { "type": "tool_use", "id": "toolu_01Wthr", "name": "get_weather", "input": { "location": "Tokyo, Japan", "forecast_days": 0 } }
  ],
  "stop_reason": "tool_use"
}
```

## Reference Implementation (Python)

```python
import requests

def get_weather(location: str, units: str = "metric", forecast_days: int = 0) -> dict:
    geo = requests.get("https://geocoding-api.open-meteo.com/v1/search",
                        params={"name": location, "count": 1}).json()
    if not geo.get("results"):
        return {"error": "location_not_found", "message": f"Could not resolve '{location}'"}

    lat, lon = geo["results"][0]["latitude"], geo["results"][0]["longitude"]
    weather = requests.get("https://api.open-meteo.com/v1/forecast", params={
        "latitude": lat, "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,weather_code",
        "temperature_unit": "celsius" if units == "metric" else "fahrenheit"
    }).json()

    current = weather["current"]
    return {
        "location": location,
        "temperature": current["temperature_2m"],
        "humidity": current["relative_humidity_2m"],
        "condition": decode_weather_code(current["weather_code"]),
        "units": units,
        "observed_at": current["time"]
    }
```

## Error Handling

| Error | Response |
|---|---|
| Location not found / ambiguous | `{"error": "location_not_found", "message": "..."}` — model should ask user to clarify |
| Upstream API timeout | `{"error": "upstream_timeout", "message": "Weather service unavailable, try again shortly"}` |
| Rate limited | `{"error": "rate_limited", "retry_after_seconds": 30}` |

Always return a structured error object rather than raising — let the model decide whether to retry, ask for clarification, or apologize to the user.

## Best Practices

- Reject coordinate-style input in the schema description to keep geocoding logic in one place.
- Cache geocoding lookups (city → lat/lon) aggressively; weather data itself should have a short TTL (5–15 min).
- Keep `forecast_days` bounded (`maximum: 7`) to prevent unbounded response sizes.
- This tool is a great candidate for **parallel tool calling** — e.g. "compare the weather in Paris and Rome" triggers two concurrent calls.
