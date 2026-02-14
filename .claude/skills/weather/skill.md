---
name: weather
description: Current weather and forecast. No API key needed. Uses wttr.in for conditions and forecast.
user-invocable: true
icon: cloud.sun
aliases: [forecast, temperature]
---

# Weather Skill

Get current weather and forecasts via wttr.in. No API keys, no dependencies, no sign-up.

## Usage

```bash
bash .claude/skills/weather/weather.sh                  # Berlin (default)
bash .claude/skills/weather/weather.sh "Cairo"           # Specific city
bash .claude/skills/weather/weather.sh "Tokyo" full      # Detailed 3-day forecast
```

## Use Cases
- "What's the weather?"
- "Should I bike today?"
- "What's the weather in Cairo this week?"
- Heartbeat: include in morning briefings
