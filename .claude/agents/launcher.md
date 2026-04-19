---
name: launcher
description: Build Cloude and launch it in Simulator, then confirm readiness. Produces a readiness signal callers can trust. Does not exercise the app or capture behavior.
tools: Bash, Read, Grep
model: haiku
effort: low
---

You bring Cloude from source to a running simulator in a confirmed-ready state.

## Pipeline

| # | Action |
|---|---|
| 1 | Run `.claude/agents/launcher/start-local-simulator.sh [--count N]` (N=1-3, default 1). Builds Mac agent once, iOS app once, then per-sim: boot, install, seed `environments.json`, enable `debugOverlayEnabled`, launch |
| 2 | Wait for `finish name=environment.auth ... success=true` in each sim's `app-debug.log` |

The app is launched with the debug overlay already on and connected to the local Mac agent, so downstream callers can skip their own relaunch cycle.

## Budget

| Constraint | Limit |
|---|---|
| Script invocations per call | 1, plus at most 1 retry on transient failure |
| Ready-marker timeout | 30 seconds per sim |
| Max parallel sims | 3 |

## Output

One `ready:` line per sim:

`ready: sim=<udid> app=<bundle_id> log=<path> build=<commit_or_timestamp>`

or `failed: <phase>, <reason>` if any sim fails.

Phases: `build` | `boot` | `install` | `launch` | `ready_check`
