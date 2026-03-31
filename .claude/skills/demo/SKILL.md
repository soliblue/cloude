---
name: demo
description: Plan and script short, high-signal Cloude demo GIFs from real app interactions for a landing page or promo video.
user-invocable: true
metadata:
  icon: film.stack.fill
  aliases: [gifs, landing-demo, promo, recording]
argument-hint: "[goal or surface to demo]"
---

# Demo

Create short portrait demo clips that show real Cloude capabilities clearly and finish fast.

## Use When

Use this skill when the user wants to:

- record GIFs or short promo clips
- demo the real app instead of mocked UI
- script prompts that produce visually strong on-screen actions
- plan later speed edits for a landing page video

## Rules

- Prefer real app capabilities over staged copy.
- Keep each clip focused on one capability cluster.
- Aim for 6 to 12 seconds per raw clip before editing.
- Prefer prompts that create visible tool cards, diffs, task lists, whiteboard changes, screenshots, notifications, clipboard actions, or browser opens.
- Avoid long builds, installs, or tests unless the user explicitly wants them.
- Bias toward prompts that end in a strong final frame.

## Workflow

### 1. Pick The Capability Mix

Default first batch:

1. real repo edit
2. whiteboard diagram
3. iPhone-native actions

If the user wants a broader set, add:

4. visible task-list workflow
5. screenshot plus summary

### 2. Write Recording Prompts

Use prompts like these and adapt paths or URLs to the current repo:

```text
Open the landing page in this repo, improve one weak sentence, make the edit directly, and show me the exact diff before you finish.
```

```text
Scan this repo and give me the three most important architecture areas. Use a task list while you work and keep the final answer short.
```

```text
Create a whiteboard diagram of Cloude's architecture with the iPhone app, macOS agent, Linux relay, Claude Code, and Cloudflare Tunnel. Label the data flow clearly.
```

```text
Copy https://soli.blue to my clipboard, open it, send a short iOS notification saying Demo ready, and trigger a light haptic when you're done.
```

```text
Read the README, summarize how remote connectivity works in two short paragraphs, then take a screenshot.
```

### 3. Add Shot Notes

For each prompt, provide:

- what should happen on screen
- the best end frame
- a 3 to 5 word caption
- what to trim or speed up later

### 4. Optimize For Editing

When planning the later video pass:

- speed idle search or output sections to 1.5x to 3x
- leave send, tool appearance, diff reveal, and final state at normal speed
- hold the final frame for 0.2s to 0.4s
- keep captions extremely short
- split or drop any clip that still feels slow after trimming

## Output Format

When using this skill, give the user:

1. a prioritized clip list
2. the exact prompts to send
3. what should appear on screen for each clip
4. short edit notes for later speed changes

## Cloude-Specific Bias

Strong Cloude demo surfaces:

- live tool execution
- task list updates
- real file edits and diffs
- whiteboard generation
- iOS actions like clipboard, open, notification, haptic, screenshot
- repo-aware reasoning from the actual project

Weak promo surfaces:

- long static text answers
- slow setup work
- anything that looks like a generic chat app
