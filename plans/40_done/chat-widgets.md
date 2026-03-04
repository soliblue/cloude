# Chat Widgets (Interactive Elements in Responses)
<!-- build: 82 -->

## Summary
Plugin system for rich interactive elements in chat. Claude calls widget "tools" via Bash, they render as native SwiftUI views inline in the conversation. Stateless, locally interactive, zero protocol pollution. iOS-only changes + a skill file.

## Architecture

**Mental model**: Each widget is a Bash tool call that iOS detects and renders as a custom view instead of a pill.

**Flow**:
1. Skill file defines available widgets + their JSON schemas
2. Claude calls Bash: `cloude widget function-plot '{"expression":"sin(x)",...}'`
3. Mac agent passes through as normal Bash tool call (no changes needed — `handleCloudeCommand` logs "Unknown" and the toolCall broadcasts as usual)
4. iOS receives `toolCall(name: "Bash", input: "cloude widget function-plot ...")`
5. iOS detects `cloude widget` prefix in Bash input → parses widget type + JSON → renders native SwiftUI view instead of pill

**Zero backend changes**: The existing tool call pipeline handles everything. Mac agent is just a pass-through. iOS is the only app that changes.

**Plugin registry on iOS**: `[String: (String) -> AnyView]` dictionary. Widget type name → view builder from JSON string. Adding a widget = one SwiftUI file + one registry entry.

## Widgets (v1)

### 1. Function Plot (`function-plot`)
Interactive 2D graph with parameter sliders.

```json
{
  "expression": "a * sin(b * x + c)",
  "params": {
    "a": {"value": 1, "min": -5, "max": 5, "step": 0.1},
    "b": {"value": 1, "min": 0.1, "max": 10, "step": 0.1},
    "c": {"value": 0, "min": -3.14, "max": 3.14, "step": 0.1}
  },
  "xRange": [-10, 10],
  "yRange": [-5, 5]
}
```

- SwiftUI Charts line graph
- Slider per parameter, live curve update
- Pinch to zoom, drag to pan
- Expression parser evaluates math on-device

### 2. Fill in the Blank (`fill-in-blank`)
Tap-to-reveal learning cards.

```json
{
  "text": "The capital of France is ___. It sits on the ___ river.",
  "blanks": ["Paris", "Seine"],
  "hint": "European geography"
}
```

- Blanks render as tappable underlined slots
- Tap a blank → reveals the answer with a subtle animation
- "Reveal all" button at bottom
- Optional hint text at top

### 3. Interactive Function (`interactive-function`)
Parameter inputs with live computed output — like a mini calculator.

```json
{
  "name": "BMI Calculator",
  "inputs": {
    "weight": {"value": 70, "unit": "kg", "min": 30, "max": 200},
    "height": {"value": 175, "unit": "cm", "min": 100, "max": 220}
  },
  "formula": "weight / (height/100)^2",
  "output": {"label": "BMI", "format": "%.1f"}
}
```

- Sliders for each input with current value + unit label
- Output recomputes in real-time as sliders move
- Clean card layout with name at top

## Implementation

### Files to create
- `.claude/skills/widgets/SKILL.md` — skill defining available widgets + schemas
- `Cloude/Cloude/UI/Widgets/WidgetRegistry.swift` — type name → view mapping + widget detection logic
- `Cloude/Cloude/UI/Widgets/FunctionPlotWidget.swift` — interactive graph
- `Cloude/Cloude/UI/Widgets/FillInBlankWidget.swift` — tap-to-reveal
- `Cloude/Cloude/UI/Widgets/InteractiveFunctionWidget.swift` — sliders + computation
- `Cloude/Cloude/UI/Widgets/ExpressionParser.swift` — math expression evaluator (shared by function-plot and interactive-function)

### Files to modify (iOS only)
- `Cloude/UI/InlineToolPill.swift` — detect widget Bash calls, render full widget view instead of pill
- `Cloude/UI/ToolCallLabel.swift` — icon + color for widget tool types (optional polish)

### iOS rendering changes
In `InlineToolPill`, check if Bash tool call input starts with `cloude widget`:
- If yes: parse type + JSON from the input string, look up in `WidgetRegistry`, render the full widget view inline (not as a small pill — as a full-width card in the message)
- If no: existing pill behavior

## Expression Parser
Simple recursive descent parser for math expressions:
- Operators: `+`, `-`, `*`, `/`, `^`
- Functions: `sin`, `cos`, `tan`, `abs`, `sqrt`, `exp`, `log`
- Constants: `pi`, `e`
- Variables: any letter name (looked up from params dictionary)
- Parentheses for grouping

No external dependencies — pure Swift, ~100 lines.

## Status
- **Stage**: active
- **Priority**: medium
- **Complexity**: medium — plugin architecture is simple, expression parser is the main work
