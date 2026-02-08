# Goodreads Skill

## Summary
Skill to access Soli's Goodreads reading history via RSS feed. Fetches book data into a local CSV for search, analysis, and context about his intellectual journey.

## Approach
- RSS feed URL: `https://www.goodreads.com/review/list_rss/{user_id}?key={key}&shelf={shelf}`
- Node script fetches RSS XML, parses it, saves as CSV in `.claude/skills/goodreads/data/`
- Skill.md provides search/analysis commands using the CSV
- Data is gitignored
- On first use, ask user for their Goodreads RSS feed URL

## Status
- [x] Create skill directory + .gitignore
- [x] Build fetch script (RSS → CSV)
- [x] Build skill.md with search/analysis commands
- [ ] Test with Soli's feed
