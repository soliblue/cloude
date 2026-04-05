# Deep Trace Checklist

Use this when baseline numbers show a problem but the cause is still unclear.

Trace candidates:

- every render source involved in the path
- live-to-static handoff ordering
- tool group creation, mutation, and completion
- parser split-point movement
- state transitions that can fan out renders
- array mapping or derived work happening inside `body`
- parent-child observation chains
- stream interruption and completion paths

Questions to answer:

- which publish actually triggered the render burst
- which renders were useful versus wasted
- which updates could stay local instead of propagating
- whether the same work is being repeated in parent and child
- whether text growth is causing layout cost growth, parse cost growth, or both
