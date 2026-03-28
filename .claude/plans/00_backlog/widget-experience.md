# Widget Experience {square.grid.3x2.fill}
<!-- priority: 6 -->
<!-- tags: ui, memory -->

> Improve widget discoverability, polish, and feedback so widget interactions stay useful over time.

## Problem

Widgets are easy to lose in long chats, visually inconsistent in places, and mostly one-way: the user interacts, but Claude learns nothing from it.

## Scope

### 1. Discoverability
- help users find widgets scattered through long conversations
- consider an index, gallery, or jump surface

### 2. UI polish
- tighten spacing, shared controls, animation, dark mode, and accessibility
- make the widget set feel like one system

### 3. Interaction feedback
- feed widget outcomes back into the next user message or another lightweight local mechanism
- let Claude see what the user actually did

## Rules

- Keep the first version simple.
- Prefer local buffering over protocol complexity when possible.
- Solve retrieval and feedback before adding more widget types.

## Desired Outcome

Widgets become easier to find, nicer to use, and more valuable because Claude can react to the user's interactions.
