# Logging Checklist

## Baseline Instrumentation

Use the smallest stable set that supports before and after comparison.

- render count per source
- FPS samples from `app-debug.log`
- objectWillChange rate from `app-debug.log`
- key state transitions for the target path
- one timing marker if the metric depends on a specific boundary

## Deep Trace Mode

Use only while isolating cause.

- every meaningful view render in the affected path
- tool group lifecycle updates
- parser region movement and split boundaries
- live-to-static handoff ordering
- temporary counters around known hot loops
- state transitions that can trigger parent fanout

## Good Logging Rules

- keep before and after instrumentation identical for proof
- log causes, not just symptoms
- prefer tagged structured strings over prose
- remove or narrow probes once the round is understood
- if a new probe was decisive, document it in the plan and keep the pattern here if it will help again
