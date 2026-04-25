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

Run one simulator issue loop with the fewest moving parts that still produces evidence.

Default loop:

1. `launcher` gets the daemon and app into a known-ready state.
2. `tester` runs one concrete scenario and captures logs.
3. The main agent reads the evidence, forms the hypothesis, and adds instrumentation or code changes locally.
4. `launcher` rebuilds if needed.
5. `tester` reruns the same scenario.
6. The main agent compares before and after and decides whether the issue is fixed.

Prefer observation over inference. If the logs do not show the behavior clearly, add instrumentation and rerun instead of debating the code.

## Default Behavior

- Do not create a plan file unless the work is going to span multiple rounds or the user explicitly asks for one.
- Do not require `planner`, `analyst`, `solver`, or `reviewer` by default.
- Keep the scenario fixed across before and after runs unless the current scenario is clearly the wrong probe.
- Prefer one rich scenario over many small ones. For chat rendering and streaming issues, prefer `mixed-markdown-multi-tool.txt`. Use `smoke-hello.txt` only for launcher and connectivity checks.

## Optional Agents

Use extra agents only when they materially reduce mistakes, and only when the user wants subagents or delegation.

- `analyst`: use when the tester logs are ambiguous and you want a second pass on the evidence.
- `reviewer`: use when the fix is risky or the before and after comparison is subtle.
- `solver`: use for a bounded code change with a tight write scope that will not block the main thread.
- `planner`: use only when the issue report is too vague to choose a scenario or target signal.
- Skip `deployer` and `scribe` for normal sim rounds.

## Inputs You Want From The User

Ask for these when they are missing:

- symptom: what looks wrong
- trigger: what action reproduces it
- preferred scenario or prompt
- success criterion: what should improve
- device only or simulator reproducible

## Return

Report only what moves the investigation forward:

- scenario used
- important log lines or metrics
- hypothesis
- change made
- before and after result
- remaining risk or next probe
