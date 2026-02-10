# Claude Code Tips for Engineers - Presentation Notes

## 1. Multi-Agent VSCode Setup

![VSCode Setup](./vscode-setup.png)

### Terminal Organization
- **6-8 named terminal windows** instead of editor panes
- Each terminal runs a dedicated Claude Code instance
- Custom **names + icons** for quick identification:
  - `📦 VCPs` - Version control/packages
  - `📝 Surveys` - Survey-related work
  - `🔀 git` - Dedicated git operations
  - `💬 Slack` - Slack bot/integration
  - `👤 Character` - Character work
  - `📊 Metabase` - Database/analytics
  - `📢 Ads` - Ads-related work
  - `🎵 Music` - Music generation (shows 96/244 tracks progress!)
  - `Videos V3 - Agent One/Two` - Project-specific agents

### Git Workflow
- **Git sidebar always visible on left** to track all changes
- **Each agent only commits files it's working on** - prevents conflicts and keeps history clean
- Can see which agent made what changes

### Multi-Agent Coordination (in CLAUDE.md)

Add this to your CLAUDE.md:
> "Multiple agents are working on this project. If you encounter bugs, compilation errors, or problems in files you didn't touch - **don't fix them**. Another agent is probably working on that. Wait for my confirmation."

**Why this matters:**
- Prevents agents from "helping" by fixing each other's in-progress work
- Avoids merge conflicts and overwritten changes
- Each agent stays in its lane
- You remain the coordinator - agents ask instead of assuming

---

## 2. Project Structure for Experiments

### Separation Pattern
```
project/
├── src/                            # Production code (graduates here)
└── playground/                     # ALL experiments live here
    ├── voice_exploration/
    ├── videos_v3/
    ├── music/
    ├── slack_bot/
    └── ...
```

### Why This Works
- **Clear boundary** - `playground/` = experimental, `src/` = production
- **Experiments must earn their place** - nothing goes to `src/` until proven
- **Each experiment gets its own agent** - clear ownership and scope
- **Safe to break things** - it's a playground after all
- **Parallel exploration** - multiple agents, multiple experiments, no conflicts
- **History preserved** - even failed experiments teach you something

### What Happens to Experiments

**Three fates:**
1. **Graduates to `src/`** - experiment worked, code moves to production
2. **Stays in `playground/` as utility** - useful one-off scripts that aren't "production" (Metabase queries, Slack bots, Linear setup, etc.)
3. **Stays as reference** - didn't work out but learnings documented

### CLAUDE.md Strategy

```
ai-videos/
├── CLAUDE.md                       # ONE main context file (learnings accumulate here)
├── src/
└── playground/
    ├── voice_exploration/
    │   └── context.md              # Temporary - short-lived context for this experiment
    ├── metabase/                   # Utility scripts (lives here forever)
    └── ...
```

- **One combined CLAUDE.md** at project root - not per-experiment
- **context.md in experiments** - temporary summaries while exploring
- When experiment succeeds → learnings get **summarized into main CLAUDE.md**
- context.md is short-lived, CLAUDE.md is permanent knowledge

### Connecting to Terminal Names
- Terminal `🎵 Music` → works in `playground/music/`
- Terminal `📊 Metabase` → utility scripts, not production
- Terminal `💬 Slack` → operational stuff
- Each agent stays in its lane

---

## 3. Tips from OpenAI Presentation

### Release Notes / Versioning for Experiments
- Treat experiments like **proper software releases**
- Keep release notes documenting:
  - What you tried
  - What worked / what didn't
  - Decisions made and why
  - Lessons learned
- Helps the coding agent **learn from previous explorations**
- When starting a new experiment, Claude can read past release notes and avoid repeating mistakes

Example structure:
```
playground/voice_exploration/
├── CHANGELOG.md          # Release notes
│   # v0.1 - Tried ElevenLabs API, worked but expensive
│   # v0.2 - Added caching, reduced costs 40%
│   # v0.3 - Switched to local Whisper for transcription
├── context.md            # Current state summary
└── src/
```

### Writing Evals Early
- Define **clear evaluation criteria from the start** of the project
- Don't wait until the end to figure out "what good looks like"
- Good evals = Claude can iterate autonomously

Examples of evals:
- "Output must compile without errors"
- "All tests must pass"
- "Response time < 200ms"
- "Output matches expected format"
- "No sensitive data in logs"

### LLM as a Judge
- Use another LLM to **evaluate Claude's outputs**
- Automates quality checking
- Enables longer autonomous runs without constant human review

Flow:
```
Claude generates → LLM Judge evaluates → Pass/Fail → Claude iterates if needed
```

### Let Claude Iterate
- With good evals + LLM judge, you can **let Claude iterate as much as possible**
- Don't micromanage every step
- Set up the guardrails (evals), then let it run
- Check in on results, not process

**The combo:** Release notes (learn from past) + Evals (define success) + LLM judge (automate checking) + Iteration (let Claude try multiple approaches)

### Using Claude to Configure Claude
- "Asking Claude to configure Claude" is very effective
- Let the agent help set up its own CLAUDE.md, memory, workflows

### Agent Effectiveness
- Showed how effective agents can be when given proper context

---

## 4. Claude Configuring Claude (Live Demo)

### Example 1: Configure Rules for a Repo
- Ask Claude to set up CLAUDE.md with project-specific rules
- Claude learns the codebase and writes its own instructions

### Example 2: VSCode Keybinding
Ask Claude to add a keybinding:
> "Add a keybinding for Cmd+T that opens a new terminal in the editor area and types 'claude' so Claude is ready to go"

**Result:** One keystroke → new terminal → Claude ready

### Example 3: Git Tracking in VSCode
- Show how git sidebar helps track multi-agent changes
- Visual diff of what each agent is doing

---

## 5. Human-Operations Repo (Perfect Template)

**Repo:** `knowunity/human-operations`
**Owner:** Non-technical (Finance & HR)
**Purpose:** Automate repetitive tasks with Claude Code

### Why This is a Great Template

#### Clear File Structure with Explanations
```
human-operations/
├── CLAUDE.md           # "Claude's instruction manual" - reads every session
├── README.md           # Human instruction manual
├── .env                # API keys (never committed)
├── requirements.txt    # Dependencies
├── src/                # Automation scripts
├── cloud/              # Cloud deployment (scheduled runs)
└── plans/              # Implementation specs for Claude
```

#### CLAUDE.md Philosophy
> "Claude reads this every session. Contains rules, workflows, and lessons learned. Update it to teach Claude permanently."

- Long-term memory = CLAUDE.md
- Short-term memory = session (gone when you close terminal)
- When Claude makes mistakes → update CLAUDE.md so it remembers forever

#### Guidelines for Non-Technical Users

**"You Are Responsible"**
> Asking Claude to do something does not eliminate your responsibility. Review what Claude does before approving.

**"Never Rush"**
> Everything here is high-stakes. Take 1-2 extra hours to set up properly rather than rushing.

**"Always Test First"**
| Instead of...                  | Test with...              |
|-------------------------------|---------------------------|
| Posting to a Slack channel    | Send a DM to yourself     |
| Emailing external person      | Send to your own email    |
| Processing all records        | Process just 1-2 first    |

**"Iterate Slowly"**
> Start small (1 record) → Verify → Expand (5 records) → Verify → Full scale

#### Good vs Bad Prompts
```
Bad:  "Send birthday messages"
Good: "Send a birthday message to Sarah in #general, but send it to me first as a test"

Bad:  "Update the contracts"
Good: "Update the contract for Max Mueller - but first show me what you're going to change"
```

#### When Claude Makes Mistakes
> Tell Claude what went wrong, ask it to update CLAUDE.md with a rule to prevent this, and say "Remember this forever so you don't repeat this mistake."

#### Cloud Deployment
- Scripts can run on schedule without your laptop
- `./cloud/deploy.sh` - upload to Google Cloud
- `./cloud/schedule.sh` - set up cron triggers
- Natural language: "Schedule the birthday messages every day at 8am"

---

## 6. Building Tools for Yourself with Claude

### Mobile App → Laptop Connection
- Mobile app that connects to laptop
- Run Claude commands from your phone

### Slack Bot
- Claude-powered Slack bot for quick tasks

### Local Whisper Transcription
- Claude built a local whisper script
- Hold a button → transcribe voice
- Fast, private, local

### The Habibi Workflow (Phone → App Store in 5-10min)
```
📱 Phone: Talk to Claude
    ↓
🔀 Claude creates PR
    ↓
📱 GitHub App: Approve PR on phone
    ↓
🔄 Auto-merge to main
    ↓
⚙️ GitHub Workflows: Build + Deploy
    ↓
🍎 Submitted to App Store
    ↓
✅ New version live in 5-10 minutes
```

- All from your phone, anywhere
- GitHub workflows handle the CI/CD
- Apple submission is automated
- No laptop needed for shipping updates

---

## Demo Flow

1. **Show VSCode multi-agent setup** (the screenshot)
   - Named terminals with icons
   - Git sidebar visible
   - Different agents for different tasks

2. **Claude configuring Claude**
   - Show personal setup where Claude configured the rules
   - Demo the Cmd+T keybinding (new terminal + claude ready)

3. **Git workflow with multiple agents**
   - Show how you track changes
   - Each agent commits only its files

4. **Human-operations repo walkthrough**
   - Perfect template for non-technical users
   - CLAUDE.md as permanent memory
   - Testing guidelines
   - Cloud deployment

5. **Building tools for yourself**
   - Mobile app demo
   - Slack bot
   - Whisper transcription button
