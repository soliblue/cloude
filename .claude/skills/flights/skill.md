---
name: flights
description: Search Google Flights data for real prices and route comparisons.
user-invocable: true
metadata:
  icon: airplane
  aliases: [flight, fly, cheap-flights]
argument-hint: "[query]"
---

# Flights

Search Google Flights data through the local `fast-flights` wrapper.

## Setup

```bash
python3 -m venv /tmp/flights-venv
source /tmp/flights-venv/bin/activate
pip install fast-flights requests
```

## Usage

```bash
source /tmp/flights-venv/bin/activate
python3 .claude/skills/flights/search.py '<json>'
```

## Input

Pass JSON with:
- `currency`
- `searches`
- `label`
- `legs` as `{date, from, to}`
- `trip` as `one-way`, `round-trip`, or `multi-city`

## Workflow

1. Parse the user's request into airports, dates, and trip type.
2. Run one or more searches in a single call.
3. Present results as a clean comparison.
4. Highlight the best options.

## Tips

- Search +/- 1 or 2 days when price matters.
- Use `multi-city` for open-jaw trips.
- Use IATA airport codes.
