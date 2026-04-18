---
title: "Perf Skill Workflow And Scenario Runner"
description: "Turn the performance skill into a repeatable workflow with reusable scenarios, logging references, and runnable simulator scripts."
created_at: 2026-04-03
tags: ["performance", "skills", "automation"]
icon: gauge.with.dots.needle.bottom.50percent
build: 133
---


# Perf Skill Workflow And Scenario Runner

Tags: performance

## Goal
- Turn the performance skill into a repeatable workflow with explicit roles, reusable scenarios, and runnable simulator scripts.

## Scope
- `.claude/skills/optimize-performance/`

## Changes
- Reworked the skill into investigator, solver, and reviewer passes with proof-based rules.
- Added a reusable perf-plan template.
- Added editable scenario and logging reference files.
- Added scripts to run a scenario, summarize render logs, and document the regression flow.
- Updated the canonical mixed markdown and tool-call scenario until Haiku reliably produced exactly three groups of three tool calls.

## Verification
- `zsh -n .claude/skills/optimize-performance/scripts/run-perf-scenario.sh`
- `zsh -n .claude/skills/optimize-performance/scripts/run-perf-regression.sh`
- `zsh -n .claude/skills/optimize-performance/scripts/summarize-render-logs.sh`
- Ran `.claude/skills/optimize-performance/scripts/run-perf-scenario.sh --no-start --scenario mixed-markdown-multi-tool.txt --wait 45`
- Verified the latest conversation produced exactly 9 tool calls using only `Bash`, `Read`, and `Grep`
- Observed stable FPS around 60 during the validated scenario run

## Notes
- The runner now explicitly selects and connects the simulator environment before opening the conversation and sending the scenario.
- An unrelated local change remains in `Cloude/Cloude.xcodeproj/project.pbxproj` and was intentionally left out of this work.
