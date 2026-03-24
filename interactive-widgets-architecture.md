# Interactive Widgets Architecture

How we bring interactive widget content (timelines, quizzes, flashcards, charts, etc.) into the Knowunity chat experience.

## Core Concept

The LLM receives widget definitions as **tool calls**. It decides when a visual widget would help the student, emits a structured tool call, and the backend streams it to the Flutter app which renders it natively.

The tool doesn't execute logic - it just pipes structured data through as a `MessageSection`. The LLM fills the schema, the backend forwards it, the Flutter app routes to the right widget.

```
Student asks question
       |
       v
  LLM (with tool definitions)
       |
       v
  Tool call: { "name": "timeline", "input": { "title": "...", "events": [...] } }
       |
       v
  Backend streams as MessageSection { type: "timeline", data: {...} }
       |
       v
  Flutter detects section type, routes to TimelineWidget
       |
       v
  Native interactive widget rendered in chat
```

## Example: Timeline Widget

### Tool Definition (sent to LLM)

```json
{
  "name": "generate_timeline",
  "description": "Render a vertical timeline of events. Use when explaining historical sequences, processes with stages, or any ordered series of events.",
  "parameters": {
    "type": "object",
    "required": ["events"],
    "properties": {
      "title": { "type": "string" },
      "events": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["date", "title"],
          "properties": {
            "date": { "type": "string", "description": "Date or time label" },
            "title": { "type": "string" },
            "description": { "type": "string" },
            "color": { "type": "string", "enum": ["blue", "green", "orange", "purple", "red", "teal"] },
            "icon": { "type": "string", "description": "SF Symbol name" }
          }
        }
      }
    }
  }
}
```

### LLM Output (streamed)

Student asks: "When was World War 2?"

```json
{
  "type": "tool_use",
  "name": "generate_timeline",
  "input": {
    "title": "World War II Key Events",
    "events": [
      { "date": "Sep 1939", "title": "Germany invades Poland", "icon": "flame.fill", "color": "red" },
      { "date": "Jun 1944", "title": "D-Day", "icon": "shield.fill", "color": "blue" },
      { "date": "May 1945", "title": "Germany surrenders", "icon": "flag.fill", "color": "green" },
      { "date": "Aug 1945", "title": "Japan surrenders", "icon": "checkmark.seal.fill", "color": "green" }
    ]
  }
}
```

### Backend Implementation

**New tool file**: `internal/modules/aichat/tools/tooltimeline.go`

```go
type TimelineTool struct{}

func (t *TimelineTool) Name() ToolName        { return "generate_timeline" }
func (t *TimelineTool) Description() string    { return "Render a timeline of events" }
func (t *TimelineTool) Category() ToolCategory { return ToolCategoryFireAndForget }

func (t *TimelineTool) Parameters() *genai.Schema {
    return &genai.Schema{
        Type: genai.TypeObject,
        Properties: map[string]*genai.Schema{
            "title":  {Type: genai.TypeString},
            "events": {Type: genai.TypeArray, Items: &genai.Schema{
                Type:     genai.TypeObject,
                Required: []string{"date", "title"},
                Properties: map[string]*genai.Schema{
                    "date":        {Type: genai.TypeString},
                    "title":       {Type: genai.TypeString},
                    "description": {Type: genai.TypeString},
                    "color":       {Type: genai.TypeString},
                    "icon":        {Type: genai.TypeString},
                },
            }},
        },
    }
}

func (t *TimelineTool) Execute(ctx context.Context, opts ToolOpts, args map[string]any) (ToolResult, error) {
    return ToolResult{
        Content:  "Timeline rendered",
        Sections: []aichatmodel.MessageSection{{
            Type: constants.MessageSectionTypeTimeline,
            Data: args,
        }},
    }, nil
}
```

**Register in** `service/a_wire.go`:

```go
aichattools.NewToolRegistry(
    aichattools.NewMockExamTool(...),
    aichattools.NewQuizTool(...),
    aichattools.NewFlashcardSetTool(...),
    &aichattools.TimelineTool{},
)
```

**Add section type** `timeline` to `constants/messagesectiontype.go`.

**Flutter side**: Add `TimelineSection` widget that takes the JSON payload and renders natively.

## Tool Selection: Avoiding Cost Inflation

With many widget types (timeline, chart, quiz, flashcard, diagram, table, etc.), passing all tool definitions to every LLM call inflates input tokens and cost. Three strategies to keep it lean:

### Strategy 1: Intent Classification (already exists)

Backend-edge already has `AIChatToolCallingIntentFilter`. A lightweight first pass classifies the user's message intent, then only relevant tools are included.

```
User: "when was world war 2?"     -> intent: factual/historical  -> tools: [timeline]
User: "quiz me on photosynthesis" -> intent: practice             -> tools: [quiz, flashcard_set]
User: "explain supply and demand" -> intent: conceptual           -> tools: [chart, diagram]
User: "help me study chapter 5"   -> intent: study                -> tools: [quiz, flashcard_set, mock_exam]
```

**Pros**: Already built, simple to extend with new intent-to-tool mappings.
**Cons**: Intent classification adds latency. Rigid mapping can miss creative uses.

### Strategy 2: Keyword Heuristics (zero-cost)

No LLM call needed. Pattern match on the user message to shortlist tools:

| Keywords / Patterns | Tools to include |
|---|---|
| "timeline", "when", "history", "events", "order", "sequence" | timeline |
| "quiz", "test me", "practice", "check my understanding" | quiz, mock_exam |
| "flashcard", "memorize", "study", "review" | flashcard_set |
| "compare", "chart", "graph", "data", "statistics" | bar_chart, line_chart, pie_chart |
| "how does X work", "explain", "steps" | step_reveal, timeline |

**Pros**: Zero latency, zero cost. Easy to maintain.
**Cons**: Misses nuance. Student asking "what happened in 1945?" doesn't contain "timeline" but should get one.

### Strategy 3: Two-Tier Tool Definitions (recommended)

Always pass a **lightweight tool menu** (just names + one-line descriptions, ~50 tokens total), then only expand the full schema for the tool the LLM picks:

**Tier 1** - Always included (~50 tokens):
```json
{
  "name": "select_widget",
  "description": "Pick a widget to enhance your response",
  "parameters": {
    "type": "object",
    "properties": {
      "widget": {
        "type": "string",
        "enum": ["timeline", "quiz", "flashcard_set", "bar_chart", "line_chart", "pie_chart", "step_reveal", "diagram"],
        "description": "timeline: ordered events | quiz: test knowledge | flashcard_set: study cards | bar_chart/line_chart/pie_chart: data viz | step_reveal: step-by-step | diagram: visual explanation"
      }
    }
  }
}
```

**Tier 2** - If LLM selects a widget, make a follow-up call with just that widget's full schema.

**Pros**: Fixed ~50 token overhead regardless of widget count. Full schema only when needed.
**Cons**: Extra round-trip when a widget is selected (but this is the minority of messages).

### Hybrid Approach

Combine strategies for best results:

1. **Keyword heuristics** as fast pre-filter (zero cost)
2. **Intent filter** as fallback when keywords don't match (existing infra)
3. **Two-tier** for the long tail when you have 10+ widget types
4. **Always pass** quiz + flashcard_set (most common, students expect them)

The goal: most messages include 0-2 tool schemas. Only edge cases need the full menu.

## Widget Catalog (Planned)

| Widget | Section Type | Use Case |
|--------|-------------|----------|
| Timeline | `timeline` | Historical events, processes, sequences |
| Quiz | `practice_set` | Knowledge testing (already exists) |
| Flashcard Set | `flashcard_set` | Memorization, review (already exists) |
| Mock Exam | `mock_exam_v2` | Full practice tests (already exists) |
| Bar Chart | `bar_chart` | Comparative data |
| Line Chart | `line_chart` | Trends over time |
| Pie Chart | `pie_chart` | Proportions |
| Step Reveal | `step_reveal` | Step-by-step solutions (math, science) |
| Diagram | `diagram` | Visual explanations, concept maps |
| Fill in Blank | `fill_in_blank` | Language learning, vocabulary |
| Ordering | `ordering` | Sequence ordering exercises |
| Matching | `matching` | Term-definition pairing |

## Small Model Considerations

We use lightweight models (gemini-2.0-flash-lite, gpt-4o-mini). Key mitigations:

- **Fewer, simpler schemas**: Keep tool parameters flat, minimize optional fields
- **Few-shot examples**: Add 1-2 examples per tool in the system prompt showing correct usage
- **Enum constraints**: Use enums for color, icon fields to reduce hallucination
- **Fallback to text**: If the model emits invalid JSON, the response still works as plain markdown
- **Test per model**: Flash-lite may need simpler schemas than Sonnet; consider per-model tool subsets
