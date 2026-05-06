---
title: "Speed Up Tester Runs"
description: "Reduce simulator tester turnaround by removing duplicate launcher work, waiting on real completion signals, and narrowing re-tests."
created_at: 2026-04-19
tags: ["agent", "skills"]
icon: gauge.with.dots.needle.bottom.50percent
build: dc6635ed
---


# Speed Up Tester Runs

## Why

The tester is currently the slowest part of a simulator round. Most of that time appears to come from orchestration overhead instead of reasoning: duplicate launcher work, fixed sleeps, and oversized regression scenarios.

## Current Friction

- The sim pipeline already launches the app before baseline and after runs, but the tester runner still defaults to starting the simulator stack again.
- The runner waits with fixed sleeps instead of exiting when the app logs real completion.
- `streaming-lifecycle-stress` bundles normal streaming, reconnect, and relaunch into one long path.
- Re-tests should default to the failing scenario unless the fix touched shared infrastructure.

## Plan

1. Make tester trust `app_ref` during sim runs.
   Keep a cold-start path for manual use, but stop rebuilding and relaunching by default when launcher already produced a ready app.

2. Replace fixed sleeps with log-driven waits.
   Wait for `environment.auth`, `chat.firstToken`, and `chat.complete` with a timeout fallback instead of sleeping for a fixed duration.

3. Split the longest scenario into narrower checks.
   Break `streaming-lifecycle-stress` into smaller scenarios so reconnect and relaunch can be re-run independently.

4. Keep post-fix verification targeted.
   Re-run only the failing scenario by default, and require an explicit reason for a full regression sweep.

5. Measure the gain and update the docs.
   Record before and after wall-clock time for baseline and after runs, then align the sim and tester docs with the new behavior.

## Likely Touchpoints

- `.claude/skills/sim/SKILL.md`
- `.claude/agents/tester.md`
- `.claude/agents/tester/scripts/run-perf-scenario.sh`
- `.claude/agents/tester/scripts/run-perf-regression.sh`
- `.claude/agents/tester/scenarios/streaming-lifecycle-stress.md`
- `.claude/memory/feedback_targeted_retest.md`

## Success Criteria

- Baseline and after sim rounds do not pay duplicate launcher cost inside tester.
- Scenario runs stop on observed completion or timeout, not blind waits.
- Manual cold-start testing still works when explicitly requested.
- Reconnect and relaunch checks can be run independently.
- Scoped fixes default to scoped re-tests.

## Shipped

- `dismiss-sim-alerts.sh` extracts alert dismissal as a standalone script; uses `set frontmost to true` + frontmost-verify gate so clicks don't land on VS Code or Safari when they steal focus.
- `start-local-simulator.sh` runs dismisser synchronously after warmup `openurl`, then polls each sim's `app-debug.log` for `finish name=environment.auth ... success=true` before emitting `ready:`. Also adds `--count N` (1-3) and `--skip-agent` flags for parallel sim support.
- `run-perf-scenario.sh` drops flaky background dismisser spawn; adds `--no-relaunch` flag; replaces fixed sleep with a poll loop on `chat.complete`; runs a single synchronous dismiss after `openurl`s.
- `run-scenarios-parallel.sh` dispatches multiple `udid:scenario` pairs in parallel via `run-perf-scenario.sh --no-start --no-relaunch`.
- `tester.md` and `launcher.md` updated to document `--no-start --no-relaunch`, parallel dispatch, and targeted re-test policy.
- `NotificationManager.swift` skips `requestAuthorization` when `CLOUDE_SKIP_PROMPTS=1` to suppress the notification permission dialog during simulator runs.
- Verified: launcher runs clean on fresh sim with no lingering prompt, auth-ready lands ~0s post-dismiss, scenario completes end-to-end in 25s.
