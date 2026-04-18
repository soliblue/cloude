# Abort and Stop-Run Behavior

Verify that invoking stop-run mid-stream cleanly halts the current response.

1. Send `prompts/long-repo-read.txt`.
2. Wait until streaming has started and at least one tool call is visible.
3. Invoke `open-simulator-url.sh stop-run` while the response is streaming.
4. Observe whether the response halts cleanly or corrupts.

## Assertions

- response stops within a reasonable time after stop-run
- live bubble finalizes (not stuck)
- no duplicated content
- subsequent messages work normally
