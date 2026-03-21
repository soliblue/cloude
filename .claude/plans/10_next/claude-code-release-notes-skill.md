# Claude Code Release Notes Skill

Create a skill that retrieves Claude Code release notes from Anthropic, parses CLI changes, and automatically updates the Cloude app to fix compatibility issues.

## Desired Outcome
A `/release-notes` skill that fetches the latest Claude Code changelog, identifies breaking or behavioral changes to the CLI, and either auto-fixes affected code in the Cloude codebase or surfaces what needs manual attention.

## Goals
- Fetch Claude Code release notes (npm changelog, GitHub releases, or Anthropic docs)
- Parse for CLI-relevant changes (new flags, removed options, output format changes, protocol changes)
- Cross-reference with Cloude's CLI integration code (Mac agent, Linux relay, iOS app's message parsing)
- Auto-apply fixes or generate a plan for manual changes

## Approach
- Web fetch from npm (`@anthropic-ai/claude-code` changelog) or GitHub releases
- Diff current CLI version vs latest
- Grep Cloude codebase for affected CLI flags, output patterns, or protocol assumptions
- Generate fixes or a report

## Files
- `.claude/skills/release-notes.md` (the skill definition)
- `Cloude Agent/Services/` (CLI process management)
- `linux-relay/` (CLI spawning and output parsing)
- `CloudeShared/` (shared message models)

## Open Questions
- Best source for release notes (npm, GitHub, docs site)?
- Should it auto-fix or just report?
- Run on heartbeat or manual only?
