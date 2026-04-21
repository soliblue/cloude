# chat-send-smoke

End-to-end: configure a focused session via deep links, send a trivial prompt, confirm stream completes.

## Run

```
./scripts/run-perf-scenario.sh --scenario smoke-hello.txt --wait 60
```

## Assertions

- `app-debug.log` contains `start name=chat.send`
- `app-debug.log` contains `finish name=chat.firstToken`
- `app-debug.log` contains `finish name=chat.complete`
- Time from send to first token < 8000 ms on haiku
- No `ERROR` lines under category Connection

## Metrics

| metric | source |
|---|---|
| chat.firstToken durationMs | grep `finish name=chat.firstToken` |
| chat.complete durationMs | grep `finish name=chat.complete` |
