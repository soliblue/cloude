---
name: reflect
description: Analyze and reorganize memories. Reviews CLAUDE.md, CLAUDE.local.md, and recent conversations for better structure and things worth remembering.
user-invocable: true
icon: brain.head.profile
aliases: [remember, memories, organize, tidy]
---

# Reflect Skill

Analyze memories and recent conversations. Suggest reorganization and surface things worth remembering.

## What This Skill Does

1. Reads both memory files (CLAUDE.md and CLAUDE.local.md)
2. Scans recent conversation history for memorable content
3. Spawns a **Sonnet worker** to analyze everything
4. Proposes:
   - Memory reorganization (grouping, splitting, hierarchy)
   - New memories from recent chats (decisions, preferences, solutions)
   - Stale entries to consider removing
5. Presents changes for user approval before writing

## Execution Steps

### 1. Gather Memory Files

```bash
cat CLAUDE.md
cat CLAUDE.local.md
```

### 2. Gather Recent Conversations

```bash
# Get list of recent sessions (last 7 days)
find ~/.claude/projects/-Users-soli-Desktop-CODING-cloude -name "*.jsonl" -mtime -7 -type f
```

For each session, extract key content:
- User requests and decisions made
- Technical solutions found
- Preferences expressed
- Recurring topics or patterns

Focus on `type: "user"` messages and `type: "assistant"` responses with significant content.

### 3. Spawn Sonnet Worker for Analysis

Use `claude --model sonnet` to analyze:

```bash
claude --model sonnet --print "
You are analyzing memories and recent conversations for a Claude Code project.

## Current Memories

### CLAUDE.md (project)
$CLAUDE_MD_CONTENT

### CLAUDE.local.md (personal)
$CLAUDE_LOCAL_MD_CONTENT

## Recent Conversation Excerpts
$CONVERSATION_EXCERPTS

## Task

Analyze and return a JSON object with:

1. **reorganization**: Suggested changes to existing memory structure
   - section: which section
   - action: 'merge' | 'split' | 'rename' | 'move_items' | 'create_subsection'
   - subsection: (for create_subsection) the ### header name
   - items_to_move: (for create_subsection) which items to group under it
   - details: what specifically to change
   - reason: why this helps

2. **new_memories**: Things from recent conversations worth remembering
   - content: the memory text (concise, actionable)
   - section: where it should go
   - source: which conversation/topic it came from
   - reason: why it's worth remembering

3. **stale**: Entries that may be outdated
   - content: the existing entry
   - section: where it is
   - reason: why it might be stale
   - suggestion: 'remove' | 'update' | 'keep'

4. **summary**: Brief overall assessment (2-3 sentences)

Guidelines:
- Focus on actionable, useful memories
- Don't suggest adding trivial things
- Respect the existing voice/style
- CLAUDE.local.md is personal (preferences, history, identity)
- CLAUDE.md is project docs (architecture, workflows, code style)
- Be conservative with deletions

**SF Symbol Icons for Sections:**
- Both root sections (##) and subsections (###) can have SF Symbol icons: `## Section {icon}` or `### Subsection {icon}`
- Example: `## Identity {person.fill}`, `### Working Style {gearshape.fill}`
- The iOS Memories UI renders these as icons next to section titles
- Pick meaningful icons that represent the content

**Hierarchy with ### Subsections:**
- The iOS Memories UI renders ### headers as nested collapsible sections
- **Bold text** does NOT create hierarchy - it renders as flat items
- Structure: ## Section (top level) → ### Subsection (nested) → #### Sub-subsection (deeper)
- NEVER use **bold text:** followed by bullets to create groups - always use ### headers
- Suggest grouping when 5+ related items could be organized under a subsection

**5x5x5 Structure Rule:**
- Max 5 root sections (##)
- Max 5 subsections (###) per root
- Max 5 items per subsection
- Max 5 levels deep if needed
- When a layer exceeds 5, consolidate or restructure
- This keeps memories scannable and forces prioritization

**Uniform Depth Rule:**
- Within any node, all children must be at the same depth
- If a section has ANY subsections, ALL content must be in subsections (no loose items)
- Either: all items directly under a section, OR all subsections (which contain items)
- This prevents mixed hierarchies like "Subsection A" + loose bullet items at same level

**Consistency Rules:**
- Session History timestamps: use `**YYYY-MM-DD**:` format, no times unless critical
- Consolidate same-day entries into single bullets
- Keep bullets concise - details belong in code/docs, not memory
- Example: Session History by month (### 2026-01, ### 2026-02)

Return ONLY valid JSON, no markdown code blocks.
"
```

### 4. Present Findings

Parse the worker's JSON output and present to user:

**Summary:**
[Worker's overall assessment]

**Reorganization Suggestions:**
- Merge "Session History" entries older than 30 days into summary
- Split "Notes" into "Technical Notes" and "Philosophy"

**New Memories from Recent Chats:**
- "Prefers Sonnet over Haiku for worker tasks" → User Preferences
- "Tool grouping bug was caused by uuid vs message.id" → Notes

**Possibly Stale:**
- "2025-01-30: Started building memory system" - consider archiving

### 5. Ask for Approval

Present all suggestions to Soli in plain text and wait for approval. Do NOT apply any changes until Soli confirms which ones to proceed with.

When Soli approves changes that involve actionable work (not just memory edits), create a plan ticket in `plans/active/` or `plans/testing/` for each approved item.

Only write to files after explicit approval.

## Guidelines

- **Use Sonnet for analysis** - smart enough to find patterns, cheaper than Opus
- **Don't analyze too much history** - Last 7 days is enough
- **Never delete without asking** - even stale entries might be important
- **Preserve voice** - don't rewrite content, just reorganize
- **Be selective with new memories** - quality over quantity
- **Respect privacy** - CLAUDE.local.md is personal, be thoughtful

## Example Output

```
Reflect Analysis Complete

Summary:
Your memories are generally well-organized. Found 3 items from recent
conversations worth adding, and the Session History section could use
some consolidation.

Reorganization:
1. Session History has 15 entries from January - group under "### 2026-01" subsection
2. "Notes" section mixes technical and philosophical - create "### Technical" and "### Philosophical" subsections

New Memories Found:
1. "Always use Sonnet for worker tasks, never Haiku"
   → User Preferences (from today's conversation)
2. "Tool grouping: group by message.id not uuid"
   → Notes (technical solution from yesterday)
3. "Voice message resilience: save to Documents/pending_audio.wav"
   → Notes (implementation detail)

Possibly Stale:
1. "Moltbook last check: 2026-02-02 14:44" - auto-updates, remove?

Apply changes? [Select which to apply]
□ Consolidate January session history
□ Split Notes section
□ Add: Sonnet preference
□ Add: Tool grouping solution
□ Add: Voice resilience detail
□ Remove: Moltbook timestamp
```

## Second Opinion (Codex)

After completing your analysis, ask Codex for its perspective on the memory structure:

```bash
codex exec -s read-only -C /Users/soli/Desktop/CODING/cloude "Review CLAUDE.md and CLAUDE.local.md. Suggest improvements to memory organization, identify stale or redundant entries, and flag anything missing that should be remembered based on the codebase. Be specific."
```

Compare Codex's suggestions with the Sonnet worker's analysis. Present a unified view noting where both agree (high confidence) and where they differ (worth discussing).

## Future Enhancements

- Automatic reflection on schedule (weekly digest)
- Cross-project memory sharing
- Semantic search over memories
- Memory importance scoring
