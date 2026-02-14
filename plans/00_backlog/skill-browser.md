# Browser Automation Skill {safari}
<!-- priority: 4 -->
<!-- tags: skill, automation -->

> Control Chrome/Safari programmatically. Navigate, click, fill forms, screenshot, extract content. Inspired by OpenClaw's browser extension (Chrome CDP).

## Approach
**Option A — Chrome DevTools Protocol (CDP):** Launch Chrome with `--remote-debugging-port`, control via WebSocket. Full page interaction. Used by Playwright/Puppeteer.

**Option B — AppleScript + Safari:** Simpler, Mac-native, limited interaction but good for reading/navigating.

Start with AppleScript+Safari for simple tasks, CDP for advanced automation.

## Commands
- Open URL in browser
- Get current page title/URL
- Extract page text content
- Screenshot current page
- Fill form field / click element (CDP only)
- Run JavaScript on page (CDP only)

## Use Cases
- "Open my bank's website and check balance"
- "Screenshot this page"
- "Fill in this form with my details"
- Research automation: navigate, extract, summarize

**Files:** `.claude/skills/browser/`, AppleScript + optional CDP scripts
