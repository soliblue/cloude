---
name: sim
description: Run Cloude in Simulator through one evidence-first execution framework for guided operations and unguided end-to-end rounds.
user-invocable: true
metadata:
  icon: play.rectangle.on.rectangle
  aliases: [simulator, runtime, harness]
argument-hint: "[goal, problem, or operation]"
---

# Sim

`sim` is the local execution and validation framework for Cloude in Simulator.

Use it when the work depends on real app behavior instead of code inspection alone. The framework exists to let the agent own local app work without quality drift, whether the user wants one narrow operation or a full end-to-end round.

## Modes

- `guided`: the user names the operation and the agent stays inside that scope
- `unguided`: the user gives a problem or goal and the agent owns investigation, implementation, verification, and regression control

## Verification Doctrine

- Prefer observation over inference.
- Code that appears logically sound is not considered verified.
- If the current logs do not explain the behavior, add the missing log before guessing.
- Do not repeat the same loop without new evidence.
- Prefer one slower, well-instrumented pass over multiple speculative passes.
- In `unguided`, the agent is responsible for verification, not just implementation.
- Every serious round should leave behind better visibility, better checks, or both.
- For any serious simulator round, rebuild the current app and agent first unless the user explicitly asks for a log-only or read-only pass.

## Standard Round Model

Every serious round uses the same high-level flow:

1. investigate
2. solve
3. review

The evidence gathered, checks run, and artifacts captured depend on the round type, but the responsibility split stays the same.

## Guided Mode

Use this when the user wants a bounded operation, for example:

- build and launch the local stack
- retrieve logs
- run the smoke suite
- run one scenario
- run a perf baseline
- capture a screenshot or screen recording

Stay inside the requested scope unless a blocker forces escalation.
If the requested operation validates app behavior, rebuild first unless the user explicitly says not to.

## Unguided Mode

Use this when the user wants the framework to own the loop.

Typical loop:

1. reproduce the problem or establish the target behavior
2. gather logs and other local evidence
3. add missing instrumentation if the signal is weak
4. implement the fix or feature
5. rerun the same scenario
6. run broader regression checks
7. capture final artifacts when visual proof matters
8. document the round and remaining risk

## Round Types

These are not separate modules. They are common uses of the same framework.

- bug investigation and fix
- feature delivery
- performance-sensitive verification
- streaming and tool-call regressions
- visual capture and final proof artifacts

## Standard Folders

- `roles/`: responsibility boundaries for investigator, solver, and reviewer
- `scripts/`: runnable helpers for launch, logs, scenarios, regressions, summaries, and capture
- `references/`: doctrine, checklists, routes, IDs, and operator guidance
- `scenarios/`: reproducible prompts and flows to run in the app
- `templates/`: round document templates
- `memory/`: one concise memory document per round, including failed rounds

## Memory Rule

Before any non-trivial unguided round, read the full `memory/` folder first.
After every serious round, write one new concise memory document, even if the round failed or was rejected.

Use `memory/` for compressed lessons.
Use `.claude/plans/` for the full execution record.
