---
name: skillsmith
description: Analyze tool and skill usage patterns and suggest skill improvements.
user-invocable: true
metadata:
  icon: hammer.circle
  aliases: [forge, tools-reflect, meta-tools]
---

# Skillsmith

Reflect on tool and skill usage patterns to find worthwhile automation.

## Workflow

1. Read recent session history.
2. Read the current skills in `.claude/skills/`.
3. Analyze recurring tool sequences, gaps, and weak spots.
4. Prefer extending existing skills before creating new ones.
5. Present suggestions and wait for approval.

## Priorities

1. extend an existing skill
2. document a workflow in memory
3. create a new skill only if nothing else fits

## Rules

- Be skeptical of new skills.
- Natural tool sequences are not automatically a problem.
- Avoid one-command skills.
- Respect existing skill boundaries.
- Keep skills simple.

## Output

Present:
- repeated patterns worth addressing
- gaps in the current skill set
- extensions to existing skills
- possible promotions from memory into skills

Use `/consult codex` if a second opinion would help.
