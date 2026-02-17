---
name: travel
description: Plan trips, research destinations, build day-by-day itineraries. Creates markdown trip plans with maps, transport, costs, and local tips.
user-invocable: true
icon: airplane.departure
aliases: [trip, vacation, holiday]
parameters:
  - name: destination
    placeholder: Where to?
    required: false
---

# Travel Skill

Plan and manage trips. Creates detailed markdown itineraries with transport, accommodation, activities, costs, and local tips.

## Trip Files

All trip plans live in `.claude/skills/travel/trips/`:
```
trips/
  morocco-feb-2026.md    # Full itinerary
  japan-apr-2026.md      # Future trips
  ...
```

## Capabilities

### Research & Planning
- Research destinations using web search
- Build day-by-day itineraries with specific times, places, costs
- Find transport options between cities (buses, trains, flights) with booking links
- Research accommodation (hostels, hotels, riads) with prices
- Check weather, Ramadan/holiday impacts, visa requirements
- Get population and vibe of each city

### Visual
- Generate city/route maps using the image skill
- Create visual mood boards for destinations

### Sync to Apple Notes
Write the trip plan to Apple Notes for offline access on iPhone:
```applescript
tell application "Notes"
    set targetFolder to first folder whose name is "Notes"
    make new note at targetFolder with properties {name:"Trip Name", body:"<content>"}
end tell
```

### Update Existing Notes
When the user has an existing trip note in Apple Notes, update it via AppleScript:
```applescript
tell application "Notes"
    set targetNote to first note whose name contains "Trip Name"
    set body of targetNote to "<updated content>"
end tell
```

## Workflow

1. **Research phase**: Web search for destinations, transport, accommodation, activities
2. **Draft itinerary**: Create day-by-day plan in `trips/{destination}.md`
3. **Enhance**: Add specific restaurant names, entry fees, opening hours, local tips
4. **Sync**: Push final plan to Apple Notes for offline iPhone access
5. **Iterate**: Update the markdown file as plans change, re-sync to Notes

## Trip File Format

```markdown
# {Destination} Trip — {dates}

## Overview
- **Dates**: ...
- **Route**: City A → City B → City C
- **Budget**: estimated total
- **Travelers**: who

## Pre-Flight Checklist
- [ ] Booking confirmations
- [ ] Passport valid
- [ ] Travel insurance
- [ ] Offline maps downloaded
- [ ] Local SIM/eSIM
- [ ] Cash/currency

## Day 1 — {Date} — {City}
### Morning
- Activity (cost, hours, tips)
### Afternoon
- Activity
### Evening
- Dinner spot (price range)
### Transport
- How to get here/leave
### Accommodation
- Name — price/night, booking link

## City Guide: {City Name}
- **Population**: X
- **Vibe**: ...
- **Weather (month)**: ...
- **Top restaurants**: ...
- **Local tips**: ...
- **Ramadan/holiday notes**: ...

## Survival Tips
- Scam awareness
- Money & bargaining
- Food safety
- Cultural norms

## Budget Breakdown
| Category | Estimated | Actual |
|----------|-----------|--------|
| Flights  | €X        |        |
| Accommodation | €X   |        |
| Transport | €X       |        |
| Food     | €X        |        |
| Activities | €X      |        |
| **Total** | **€X**   |        |
```

## Notes Integration

The markdown file is the source of truth. Sync to Apple Notes when:
- Initial plan is ready
- Major changes are made
- User asks to update the note

Apple Notes format uses HTML — convert markdown headers to `<h2>`, bullets to `<ul><li>`, etc. See the notes skill for formatting details.
