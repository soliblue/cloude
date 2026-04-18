# Streaming Perf Round 5

tags: performance
status: accepted

## Goal
Automate reviewer regression coverage so the canonical mixed stream and the round-specific edge case run from one command instead of a manual multi-step checklist.

## Reproduction
- Baseline: `.claude/skills/optimize-performance/scripts/run-perf-regression.sh`
- After: `.claude/skills/optimize-performance/scripts/run-perf-regression.sh --scenario agent-group-completion.txt --wait 45`

## Instrumentation
- No app instrumentation changes
- Baseline and after both rely on the existing scenario runner summaries

## Baseline Numbers
- Starting point: local commit `2b5719bc`
- Reviewer automation: `0` scenarios executed automatically
- Required manual review steps from the old script: `4`
- Canonical edge coverage encoded in shared scenarios: `1`

## Root-Cause Hypothesis
Reviewer regression drift was coming from process, not app code. The old regression script only printed instructions, so the canonical scenario ran only when someone remembered to execute each step manually.

## Fix
Make the regression runner execute the canonical mixed-tool scenario plus one explicit secondary scenario, and add a dedicated agent-group completion scenario so the known edge case stays encoded in shared artifacts.

## Consultation Summary
Codex agreed that reducing friction is useful, but challenged the idea of making the second scenario optional. The fix changed to require an explicit extra scenario and to label the output as a triage aid rather than a pass or fail verdict.

## After Numbers
- Reviewer automation: `2` scenarios executed automatically
- Manual review steps from the wrapper: `1` command
- Canonical edge coverage encoded in shared scenarios: `2`

## Regression Results
- `run-perf-regression.sh --scenario agent-group-completion.txt --wait 45 --model haiku` completed successfully
- The wrapper ran the canonical mixed scenario and the new agent-group completion scenario in sequence
- Summaries still come from the existing scenario runner, so no app behavior changed

## Approval
Accepted.

## Shared Artifact Updated
- `.claude/skills/optimize-performance/scripts/run-perf-regression.sh`
- `.claude/skills/optimize-performance/scenarios/agent-group-completion.txt`
- `.claude/skills/optimize-performance/SKILL.md`
