---
name: test
description: Show what needs testing and move verified items to done.
user-invocable: true
metadata:
  icon: checkmark.diamond
  aliases: [check, testing]
---

# Test

`plans/30_testing/` is the source of truth for what needs testing.

## Flags

- `/test`: show what is ready to test
- `/test --run`: run tests first
- `/test --done <name>`: move a plan from testing to done

## Run Tests

```bash
xcodebuild test -project Cloude/Cloude.xcodeproj -scheme Cloude -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -20
```

Report pass or fail clearly.

## Show What Needs Testing

1. Get the current build number with `cd Cloude && agvtool what-version -terse`.
2. Read plans in `plans/30_testing/`.
3. A feature is testable if it has `<!-- build: X -->` and `X <= current build`.
4. For each testable item, provide:
   - feature name
   - what changed
   - minimal test steps
   - expected result

## After Testing

- Move passed plans from `plans/30_testing/` to `plans/40_done/`.
- If many items are waiting, prioritize testing before adding more.
