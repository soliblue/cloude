# chat-tool-read

Verify a turn that invokes a Read tool completes and produces a tool_use + tool_result pair.

## Run

```
./scripts/run-perf-scenario.sh --scenario tool-read-one-file.txt --wait 90
```

## Assertions

- `finish name=chat.complete` present
- At least one `applyToolResult` (inspect daemon log or iOS ChatToolCall state); evidence: a `ChatToolCall` with `state=.complete` exists in memory for the session (visual confirmation via screenshot if needed)

## Metrics

| metric | source |
|---|---|
| chat.complete durationMs | grep `finish name=chat.complete` |
