# Streaming Lifecycle Stress

Multi-turn flow stressing streaming, reconnect, and relaunch. Run every step in order. Do not substitute prompts unless the round explicitly needs a variant.

## Message 1

1. Send `prompts/mixed-markdown-multi-tool.txt`.
2. Wait for the response to finish normally.

## Message 2

1. Send `prompts/mixed-markdown-multi-tool.txt` again.
2. Wait until streaming has started and at least one tool call is visible.
3. Disconnect the selected environment.
4. Wait briefly.
5. Reconnect the same environment.
6. Keep the app open and let the response continue if it recovers.
7. Record whether the response resumes, duplicates, stalls, or finalizes incorrectly.

## Message 3

1. Send `prompts/agent-group-completion.txt`.
2. Wait until the response is visibly streaming and at least one agent tool call is active.
3. Terminate the app.
4. Relaunch the app.
5. Reopen the same conversation if needed.
6. Observe whether the in-flight response recovers, duplicates, disappears, or corrupts the live-to-static handoff.

## Assertions

- no duplicated markdown sections
- no duplicated tool groups
- no missing trailing text after tools
- no stuck live bubble after completion
- no corruption when reconnecting during Message 2
- no broken recovery semantics during Message 3 relaunch
- correct final ordering of text, tool groups, and completion state
- stable render counts after handoff
