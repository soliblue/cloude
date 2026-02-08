# Tweets Skill
<!-- priority: 10 -->
<!-- tags: skills -->
<!-- build: 56 -->

## Summary
Create a `/tweets` skill that provides access to Soli's Twitter archive for context, analysis, and conversation. The tweet data should be available locally but never pushed to git.

## Requirements

### Data Setup
- Symlink or copy the tweet archive from `/Users/soli/Desktop/CODING/tweets/` into the project (e.g., `.claude/skills/tweets/data/`)
- Add the data path to `.gitignore` so it never gets committed (public repo — tweets contain personal data)
- Parse `tweets.js` and `note-tweet.js` into a usable format (JSON without the `window.YTD` prefix)

### Skill Capabilities
- **Search tweets** by keyword, date range, or engagement threshold
- **Get full text** of long-form tweets (note-tweets) that are truncated in the main archive
- **Analyze patterns** — obsession cycles, topic frequency, sentiment over time
- **Use for context** — when interviewing, learning about Soli, or writing in his voice, pull relevant tweets
- **Stats** — total tweets, most liked, most retweeted, posting frequency by period

### Technical Notes
- Tweet archive location: `/Users/soli/Desktop/CODING/tweets/twitter-2026-01-06-2f330bc3d23cb832ac07e77324c2bebe7b3e8f0ea0a1e4d337b73cb0f0bf0a14/data/`
- Key files: `tweets.js` (462 original tweets), `note-tweet.js` (39 long-form notes)
- Files have `window.YTD.tweets.part0 = ` prefix that needs stripping before JSON parse
- Reply tweets start with `@` and have `in_reply_to_user_id` set
- Truncated tweets have full text in `note-tweet.js`, matched by tweet ID

### Privacy
- **CRITICAL**: Tweet data must be gitignored. This is a public repo.
- The skill definition (`skill.md`) can be public, but data files must not be committed
