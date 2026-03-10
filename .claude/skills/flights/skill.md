---
name: flights
description: Search for cheap flights using Google Flights data. No API key needed. Compares prices, dates, and routes.
user-invocable: true
icon: airplane
aliases: [flight, fly, cheap-flights]
parameters:
  - name: query
    placeholder: e.g. Berlin to Cairo April 28
    required: false
---

# Flights Skill

Search Google Flights for real prices. No API key, no signup. Uses the `fast-flights` Python package to scrape Google Flights via protobuf encoding, with EU consent bypass for German servers.

## Setup

Requires a Python venv with dependencies:

```bash
python3 -m venv /tmp/flights-venv
source /tmp/flights-venv/bin/activate
pip install fast-flights requests
```

If `/tmp/flights-venv` already exists, just activate it.

## Usage

```bash
source /tmp/flights-venv/bin/activate
python3 .claude/skills/flights/search.py '<json>'
```

### JSON Input Format

```json
{
  "currency": "EUR",
  "searches": [
    {
      "label": "BER → HRG one-way Apr 28",
      "legs": [{"date": "2026-04-28", "from": "BER", "to": "HRG"}],
      "trip": "one-way"
    },
    {
      "label": "VIE → HRG → VIE round trip",
      "legs": [
        {"date": "2026-04-28", "from": "VIE", "to": "HRG"},
        {"date": "2026-05-03", "from": "HRG", "to": "VIE"}
      ],
      "trip": "round-trip"
    },
    {
      "label": "Multi-city BER → HRG → VIE",
      "legs": [
        {"date": "2026-04-28", "from": "BER", "to": "HRG"},
        {"date": "2026-05-03", "from": "HRG", "to": "VIE"}
      ],
      "trip": "multi-city"
    }
  ]
}
```

### Parameters

- **currency**: EUR, USD, GBP, etc.
- **trip**: `one-way`, `round-trip`, or `multi-city`
- **legs**: array of `{date, from, to}` using YYYY-MM-DD dates and IATA airport codes
- **label**: human-readable name for the search (used as key in output)

### Output

JSON object keyed by label, each containing an array of flights:

```json
{
  "BER → HRG": [
    {
      "name": "Eurowings",
      "departure": "11:25 AM on Tue, Apr 28",
      "arrival": "5:00 PM on Tue, Apr 28",
      "duration": "4 hr 35 min",
      "price": "€85",
      "stops": 0,
      "is_best": true
    }
  ]
}
```

## Workflow

1. Parse the user's request into search parameters (dates, airports, one-way/round-trip)
2. Ensure the venv exists and is activated
3. Run multiple searches in one call (batch different date combos, routes, etc.)
4. Present results in a clean comparison table
5. Highlight the best deal

## Tips

- Search +/- 1-2 days around the target date to find cheaper options
- For open-jaw trips (fly into A, out of B), use `multi-city`
- Run multiple searches in one call to avoid repeated consent handshakes
- Airport codes: use IATA codes (BER, VIE, HRG, CAI, CDG, LHR, JFK, etc.)
- If the venv is gone (server reboot), recreate it
