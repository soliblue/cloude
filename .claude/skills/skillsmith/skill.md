---
name: skillsmith
description: Analyze tool/skill usage patterns and suggest new skills or extensions. Uses a worker model to reflect on session history.
user-invocable: true
icon: hammer.circle
aliases: [forge, tools-reflect, meta-tools]
---

# Skillsmith

Reflect on tool and skill usage patterns. Analyze session history to discover repetitive workflows, gaps, and opportunities for new skills or extensions.

## What This Skill Does

1. Reads recent session history (JSONL files)
2. Reads all existing skills
3. Spawns a worker model (Sonnet) to analyze patterns
4. Returns structured suggestions for:
   - New skills based on repetitive patterns
   - Extensions to existing skills
   - Gaps in current tooling
   - Workflows that should be automated

## Execution Steps

### 1. Gather Data

```bash
# Get list of recent sessions (last 7 days)
find ~/.claude/projects/-Users-soli-Desktop-CODING-cloude -name "*.jsonl" -mtime -7 -type f

# Read all skill definitions
ls -la .claude/skills/
```

For each skill, read its skill.md to understand what it does.

### 2. Extract Tool Patterns

Parse the JSONL files to extract:
- Tool call sequences (which tools are called together)
- Tool call frequencies (which tools are used most)
- Common arguments/patterns in tool inputs
- Skill invocations and their contexts

Focus on `type: "assistant"` entries with `tool_use` content blocks.

Example extraction (pseudocode):
```
For each session file:
  For each line where type == "assistant":
    For each content block where type == "tool_use":
      Record: tool_name, input_summary, timestamp

Group consecutive tool calls into sequences
Count frequency of each sequence
```

### 3. Spawn Worker Model for Analysis

Use `claude --model sonnet` to analyze the extracted patterns:

```bash
claude --model sonnet --print "
You are analyzing tool usage patterns for a Claude Code project.

## Current Skills
$SKILLS_LIST

## Tool Call Patterns (from last 7 days)
$TOOL_PATTERNS

## Task
Analyze these patterns and return a JSON object with:

1. **patterns**: Repetitive tool sequences that happen frequently
   - sequence: array of tool names
   - frequency: how often this happens
   - suggestion: what skill could automate this

2. **gaps**: Missing automation opportunities
   - description: what's being done manually
   - suggestion: what skill would help

3. **extensions**: Ways to improve existing skills
   - skill: which skill to extend
   - suggestion: what to add (flags, variants, etc.)

4. **promotions**: Things from CLAUDE.local.md that should become skills
   - workflow: what's documented as a manual process
   - suggestion: how to codify it

Return ONLY valid JSON, no markdown code blocks.
"
```

### 4. Present Findings

Parse the worker's JSON output and present to user:

**Detected Patterns:**
- `grep → read → edit` happens 12 times → suggest: `/hunt` skill
- `git status → git add → git commit` happens 8 times → already covered by `/push`

**Gaps:**
- No skill for "show changes since last deploy"
- No skill for "undo recent file changes"

**Extensions:**
- `/deploy` could have `--mac-only` flag
- `/status` could show recent tool usage stats

**Promotions:**
- Moltbook workflow in CLAUDE.local.md → formalized in `/moltbook`

### 5. Offer to Implement

**Priority order** (always prefer higher options):
1. **Extend existing skill** - Add a flag, variant, or small feature
2. **Add to memory** - Document as a workflow if not worth a skill
3. **Create new skill** - Only if truly nothing else fits

Be skeptical of new skill suggestions. Ask: "Could this just be an extension to /deploy, /status, /push, or /refactor?"

Use AskUserQuestion to let user pick which suggestions to implement.

## Guidelines

- **PREFER EXTENSIONS OVER NEW SKILLS** - Most patterns can be handled by extending existing skills. Only suggest a new skill when there's truly nothing to extend.
- **Be critical of new skill suggestions** - Ask: "Is this really worth its own skill, or is it just a one-liner that's fine as-is?"
- **Many patterns don't need automation** - `Grep → Read → Edit` is natural flow, not a problem to solve
- **Use Sonnet for analysis** - It's cheaper and faster for data crunching
- **Don't analyze too much history** - Last 3-7 days is enough
- **Respect existing skills** - Don't suggest duplicates
- **Keep skills simple** - A skill that does one thing well > complex multi-tool
- **Preserve manual control** - Some things shouldn't be automated

### Anti-patterns to avoid suggesting:
- Skills that wrap a single command (`/build` for just `xcodebuild`)
- Skills for natural tool sequences that work fine manually
- Skills that duplicate what existing skills already do
- Over-engineered solutions for simple problems

## Example Output

```
Skillsmith Analysis Complete

Patterns Found:
1. Read → Edit → Bash(build) [8 occurrences]
   → Suggestion: /quick-fix skill for edit-and-verify workflow

2. Grep → Read → Read → Read [15 occurrences]
   → Suggestion: /hunt skill that greps then auto-reads matching files

3. git diff → git add → git commit [12 occurrences]
   → Already covered by /push skill ✓

Gaps Identified:
1. No way to see "what changed since last deploy"
   → Suggestion: /changelog skill

2. Frequently checking TestFlight status manually
   → Suggestion: Add --status flag to /deploy

Extensions:
1. /deploy could support --mac-only for agent-only deploys
2. /status could show tool usage stats

Create which skills? [Select multiple]
□ /quick-fix - Edit and verify workflow
□ /hunt - Grep and auto-read
□ /changelog - Changes since deploy
□ Extend /deploy with --mac-only
□ Extend /status with tool stats
```

## Future Enhancements

- Track skill usage over time to measure effectiveness
- Auto-suggest skill deprecation for unused skills
- Cross-project pattern analysis
- Learn from other Claude Code users (with consent)
