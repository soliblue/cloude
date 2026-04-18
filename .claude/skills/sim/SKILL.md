---
name: sim
description: Orchestrate one end-to-end investigate, solve, review round in Simulator.
user-invocable: true
metadata:
  icon: play.rectangle.on.rectangle
  aliases: [simulator, round]
argument-hint: "[goal or problem]"
---

# Sim

Runs one complete round of behavioral investigation on Cloude in Simulator: plan, measure, hypothesize, fix, verify, judge. Produces a measured fix with a pass/fail verdict.

The skill owns `.claude/plans/20_active/<slug>.md` and opens with `# Round: <goal>`. Binary artifacts land in `.claude/agents/tester/output/`; the round doc references them by path. On `approved`, move the file from `20_active/<slug>.md` to `40_shipped/<slug>.md`. On `rejected`, report the reason and ask the user to re-enter at planner (more evidence) or solver (different fix).

Prefer observation over inference: code that appears logically sound is not verified.

## Pipeline

| # | Agent | Input | Returns | Round doc | On failure |
|---|---|---|---|---|---|
| 1 | `planner` | `goal` | scope, reproduction, scenarios, target_metrics, instrumentation | `## Plan` | / |
| 2 | `launcher` | / | `ready: sim=<udid> app=<bundle> log=<path> build=<commit>` | / | / |
| 3 | `tester` | `scenarios, app_ref` | per scenario: invocation, build, metrics, assertions, notable_logs, artifacts, run_notes | `## Baseline` | / |
| 4 | `analyst` | `baseline_reports, target_metrics, scope` | hypothesis, allowed_files | `## Hypothesis` | `need_more_evidence`: add instrumentation and re-run, or abandon |
| 5 | `solver` | `hypothesis, allowed_files` | `applied: N files, M lines` | `## Implementation` | `scope_escalation`: expand `allowed_files` or abandon; `scope_too_large`: reframe |
| 6 | `launcher` | / | ready (rebuilt with fix) | / | / |
| 7 | `tester` | `scenarios, app_ref` | per scenario: invocation, build, metrics, assertions, notable_logs, artifacts, run_notes | `## After` | / |
| 8 | `reviewer` | `hypothesis, allowed_files, target_metrics, implementation_summary, baseline, after` | `approved + lesson` | `## Verdict` | `rejected`: ask user for more evidence or different fix |
