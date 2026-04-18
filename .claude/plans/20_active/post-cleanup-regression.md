# Round: Run existing scenarios to catch any regressions from recent app cleanup

## Plan

**Scope:**
- In: streaming lifecycle (send/receive/reconnect/relaunch), long markdown rendering, abort/stop-run, deep link navigation.
- Out: performance tuning, new feature behaviors, server/relay hardening, Live Activity extension.

**Reproduction:** Launch sim against `dev` build. Walk the four scenarios in order against a fresh conversation each. Compare to last green baseline. No specific failing repro; this is a sweep after recent TabView/ZStack, keyboard-transition, and dead-code removal commits.

**Scenarios:**
- `streaming-lifecycle-stress` - send, multi-tool streaming, disconnect/reconnect mid-stream, relaunch mid-stream
- `long-markdown` - long-response rendering with headings, bullets, tables
- `abort-stop-run` - stop-run mid-stream, live-bubble finalization
- `deep-link-navigation` - `cloude://file`, `cloude://git`, `cloude://git/diff` routing

**Target metrics:**
- Streaming: no duplicated markdown/tool groups, no missing trailing text, no stuck live bubble, clean reconnect in Message 2, correct relaunch semantics in Message 3, stable render counts after handoff.
- Long markdown: all 8 sections render, headings/bullets/table correct, no stuck live bubble, stable render count.
- Abort: response halts within reasonable time, live bubble finalizes, no duplication, subsequent messages stream normally.
- Deep links: each URL opens expected surface, no stale state between links, back nav works.
- Cross-cutting visual: no phantom top spacing on AI bubbles, tab swipe behavior matches spec, no layout jump on keyboard transitions.

**Instrumentation:** none. Regression sweep; adding logs would muddy comparison.
