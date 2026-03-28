# Streaming Running State Fix
<!-- build: 110 -->

Cherry-picked from fix/reconnect-streaming-state. Marks conversation as running on tool calls (not just text output) and extracts ensureRunning helper.

## Test
- [ ] Send a message that triggers tool calls: conversation shows as running immediately
- [ ] Tool-only responses (no text before tools) still show streaming UI
- [ ] Returning to foreground after backgrounding during streaming shows correct state
- [ ] Idle state still clears running state properly
