# Plan Build Tagging {number.circle}

> Tag completed plans with the build number they shipped in, so you can trace any feature back to a specific release.

## Goal
When a plan moves to `done/`, it should record which build it shipped in. This makes it easy to answer "what went out in Build 53?" or "when did we add X?".

## Open Questions
- **When to tag**: Automatically at deploy time? Or manually when moving to done?
- **Format in markdown**: `build: 53` frontmatter? Or append to heading like `# Title {icon} [B53]`?
- **Process change**: The deploy lane could auto-tag all plans in `done/` that don't have a build number yet — requires knowing current build number at deploy time
- **UI**: Show build number as a small badge on done plan cards? Filter by build?
- **Retroactive**: Should we tag existing done plans, or start fresh?

## Notes
- Build number is already bumped in the Xcode project during deploy
- Could read it from `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` in the xcodeproj
- Ties into the broader plan metadata story (descriptions, tags, build numbers)
