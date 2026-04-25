# chat-mixed-markdown-multi-tool

Preferred broader regression turn. Sends the mixed markdown + multi-tool prompt so one run exercises streaming text, repeated tool calls, and richer final rendering.

## Run

```
./scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 180
```

## Assertions

- `app-debug.log` contains `start name=chat.send`
- `app-debug.log` contains `finish name=chat.firstToken`
- `app-debug.log` contains `finish name=chat.complete`
- The final assistant turn includes multiple tool pills and completes without a connection error
- No `ERROR` lines under category Connection

## Metrics

| metric | source |
|---|---|
| chat.firstToken durationMs | grep `finish name=chat.firstToken` |
| chat.complete durationMs | grep `finish name=chat.complete` |
