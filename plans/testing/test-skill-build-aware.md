# Test Skill: Build-Aware Testing
<!-- priority: 2 -->

**Feature**: Test skill automatically filters testable features based on build number comparison.

**What changed**:
- `/test` now reads current build number via `agvtool what-version -terse`
- Parses `<!-- build: X -->` metadata from all `plans/testing/*.md` files
- Only shows features where build tag ≤ current running build
- Generates minimal testing instructions for each testable feature

**File**: `.claude/skills/test/skill.md`

**How to test**:
1. Run `/test` command
2. Verify it reports current build number (should be 56 or higher)
3. Verify it only lists features from `plans/testing/` with build tags ≤ current build
4. Check that testing instructions are concise and actionable

**Expected**: Clear list of "X items ready to test (Build YY)" with minimal instructions for each.
