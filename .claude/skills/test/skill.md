---
name: test
description: Show what needs testing and update staging after tests pass. Use when asked "what needs testing", "test", or to confirm tests passed.
user-invocable: true
icon: checkmark.diamond
aliases: [check, testing]
---

# Test Skill

Manage the testing workflow. The `plans/30_testing/` folder is the source of truth for what needs testing.

## Flags

- `/test` — show what needs testing (default), auto-detect testable features based on build number
- `/test --run` — run xcodebuild tests before showing testing status
- `/test --done <name>` — move a specific plan from testing to done

## Run Tests

When `--run` is passed (or when it makes sense before a deploy):

```bash
xcodebuild test -project Cloude/Cloude.xcodeproj -scheme Cloude -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -20
```

Report pass/fail clearly. If tests fail, show the failing test names and relevant error output.

## Show What Needs Testing

### 1. Get Current Build Number

```bash
cd Cloude && agvtool what-version -terse
```

### 2. Read All Testing Plans

Read every file in `plans/30_testing/` and extract:
- Filename (without path or extension)
- `<!-- build: X -->` metadata (if present)
- Title (first H1 heading)
- Brief description or problem statement

### 3. Filter Testable Features

Features are testable if:
- They have a `<!-- build: X -->` tag
- The build number in the tag is **≤** current running build number

Features NOT ready to test:
- No `<!-- build: -->` tag (not yet deployed)
- Build number **>** current build (deployed to newer build than what's running)

### 4. Generate Minimal Testing Instructions

For each testable feature, provide:
- **Feature name**: short, clear title
- **What to test**: 1-2 sentence description of what changed
- **How to test**: minimal steps (e.g., "Tap X, verify Y appears", "Navigate to Z, check that...")
- **Expected result**: what success looks like

Keep testing instructions concise and actionable. Avoid verbose explanations.

### 5. Send Interactive Testing Checklist

Use multiple `cloude notify` commands or a structured message to surface the testing checklist. If there are 3+ features, consider asking the user which ones to prioritize.

Show the count prominently: "**X items ready to test (Build YY)**"

## After Testing

When the user confirms items pass:

1. Move the plan file from `plans/30_testing/` to `plans/40_done/`
2. If all items tested, suggest deploying

## Blocking Rule

If 5+ items in `plans/30_testing/`:
- Don't add new features
- Tell the user to test first
- Focus on bug fixes or docs only

## After Deploy

Update "Last deploy" timestamp in CLAUDE.local.md staging section.
