# Skills Marketplace — skills.soli.blue

## Goal
Host a public Claude Code plugin marketplace on GitHub so anyone can install Cloude skills with one command.

## How It Works
- GitHub repo: `soli/cloude-skills` (or similar)
- Users add marketplace: `/plugin marketplace add soli/cloude-skills`
- Users install skills: `/plugin install image@cloude-skills`
- Free to start, monetization later (Gumroad bundles, sponsorship, or official Anthropic marketplace)

## Structure
```
cloude-skills/
├── .claude-plugin/
│   └── marketplace.json          # Catalog of all skills
├── plugins/
│   ├── image/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/image/
│   │       └── SKILL.md
│   ├── speak/
│   ├── slides/
│   ├── consult/
│   ├── manifold/
│   └── moltbook/
```

## Skills to List (v1)
- **image** — Gemini image generation
- **speak** — Kokoro local TTS + ElevenLabs cloud
- **slides** — AI slide deck generation
- **consult** — Multi-model second opinions (Codex, Claude variants)
- **manifold** — Prediction market browsing + betting
- **moltbook** — AI social platform integration

## Work Required
1. Create GitHub repo `soli/cloude-skills`
2. Extract portable versions of each skill (strip Cloude-specific dependencies)
3. Create `plugin.json` manifest for each skill
4. Create `marketplace.json` catalog
5. Write a clean README with install instructions
6. Test install flow end-to-end
7. Optional: landing page at skills.soli.blue

## Key Decisions
- **Free or paid?** Free initially — build reputation, get installs, monetize later
- **Which skills?** Only ones that work standalone (no Mac agent dependency)
- **API keys?** Skills requiring keys (Gemini, ElevenLabs) need clear setup docs
- **Branding?** "Cloude Skills" or just "soli's skills"?

## Dependencies
- Some skills use `cloude` CLI commands — need to gracefully degrade or remove
- API key requirements per skill need documentation
- Need to test each skill works in isolation outside the Cloude ecosystem
