# Skill Documentation Audit & Fixes

Comprehensive audit revealed multiple issues with skill implementation and documentation.

## High Priority Issues

### 1. Hard-coded `/Users/soli/` paths everywhere
- **Problem**: Every skill uses absolute paths that break for anyone cloning the repo
- **Files affected**: All SKILL.md files
- **Fix**: Replace with `${HOME}` or relative paths from project root
- **Example**: `.claude/skills/icon/` → `.claude/skills/icon/`

### 2. Refactor skill uses deprecated Codex pattern
- **Problem**: `refactor` skill directly calls `codex exec` instead of using `/consult codex`
- **File**: `.claude/skills/refactor/SKILL.md` line 69
- **Fix**: Update to use `/consult codex "question"` pattern

### 3. Missing `disable-model-invocation: true` on side-effect skills
- **Problem**: Skills with expensive operations can be accidentally invoked
- **Files**: `recap`, `music`, `transcribe`, `icon` skills
- **Fix**: Add frontmatter field to prevent accidental invocation

### 4. No "Available Skills" section in CLAUDE.md
- **Problem**: Users don't know what skills exist without discovering via `/`
- **Skills missing**: `music`, `transcribe`, `consult`
- **Fix**: Add comprehensive skills section to CLAUDE.md

### 5. Inconsistent git commit attribution
- **Problem**: CLAUDE.md says "Claude Code", deploy skill says "Claude Opus 4.6"
- **Fix**: Standardize on "Claude Opus 4.6 <noreply@anthropic.com>"

### 6. Video skill state unclear
- **Problem**: Skill marked `user-invocable: false` but still present with full docs
- **Decision needed**: Delete entirely or add prominent warning?

## Medium Priority Issues

### 7. Missing `argument-hint` fields
- **Problem**: No autocomplete hints for skill arguments
- **Fix**: Add hints like `argument-hint: "[--mac-only|--ios-only|--phone]"` to deploy

### 8. Duplicate git workflow docs
- **Problem**: CLAUDE.md and deploy skill both document git workflow
- **Fix**: Deploy skill should reference CLAUDE.md, not duplicate

### 9. Deleted codex skill still referenced
- **Problem**: Refactor skill references codex as if it still exists
- **Fix**: Remove codex-specific logic, use `/consult codex` pattern

### 10. Stale root skills/ folder reference
- **Problem**: CLAUDE.md mentions deprecated root `skills/` folder
- **Fix**: Remove mention entirely since migration is complete

## Low Priority Issues

### 11. Expand skill aliases for discoverability
- Example: `transcribe` could add `[speech-to-text, audio-to-text]` aliases

### 12. Font path validation in recap skill
- Problem: Assumes `/System/Library/Fonts/Helvetica.ttc` exists
- Fix: Add existence check or bundle fonts

### 13. Unnecessary venv activation in icon skill
- Problem: Line 27 activates venv but can call Python directly
- Fix: Remove activation, use direct path to Python binary

## Implementation Plan

1. Fix all hard-coded paths (batch find/replace)
2. Add missing frontmatter fields
3. Update refactor skill to use `/consult codex`
4. Add "Available Skills" section to CLAUDE.md
5. Standardize git attribution across all docs
6. Decide on video skill fate (delete vs warn)
7. Add argument-hint fields where applicable
8. Remove duplicate git workflow from deploy skill
9. Clean up stale references

## Testing

- Clone repo to different user to verify path portability
- Test all skills still work after path changes
- Verify `/consult codex` works in refactor skill
- Test that `disable-model-invocation` prevents accidental invocation

## Notes

- Official docs recommend keeping SKILL.md under 500 lines
- Use `context: fork` with `agent` field for subagent invocation (not manual CLI)
- String substitutions: `$ARGUMENTS`, `$0`, `$1` for args, `${CLAUDE_SESSION_ID}` for session ops
- Dynamic context: `` !`command` `` syntax for live command output
