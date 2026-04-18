---
title: "Test Skill: Build-Aware Testing"
description: "Made /test skill filter testable features by comparing plan build tags against the current app build number."
created_at: 2026-02-08
tags: ["skills"]
icon: hammer.fill
build: 56
---


# Test Skill: Build-Aware Testing {hammer.fill}
**Feature**: Test skill automatically filters testable features based on build number comparison.

**What changed**:
- `/test` now reads current build number via `agvtool what-version -terse`
- Parses `build: X` front matter from all `plans/testing/*.md` files
- Only shows features where build tag ≤ current running build
- Generates minimal testing instructions for each testable feature

**File**: `.claude/skills/test/skill.md`

**How to test**:
1. Run `/test` command
2. Verify it reports current build number (should be 56 or higher)
3. Verify it only lists features from `plans/testing/` with build tags ≤ current build
4. Check that testing instructions are concise and actionable

**Expected**: Clear list of "X items ready to test (Build YY)" with minimal instructions for each.
