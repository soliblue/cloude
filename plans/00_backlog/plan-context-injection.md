# Plan Context Injection {doc.text.magnifyingglass}
<!-- priority: 3 -->
<!-- tags: ui, plans, chat -->

> Search results include plan tickets — tapping a plan injects its content into the chat context.

## Problem

Plans contain valuable context (architecture decisions, implementation details) but live in files. When chatting, you'd have to manually reference them. Should be seamless.

## Plan

- Search (from conversation-search) also indexes plan files
- Plan results show title + stage (next/active/done)
- Tapping a plan injects its markdown content into the current chat input or context
- Details TBD when we get to implementation

## Codex Review

**Key Findings (Highest Risk First)**
1. `Undefined injection model` (high): "injects into input or context" is the core behavior but still TBD. This affects UX, safety, token usage, and implementation architecture. Decide this first.
2. `Prompt-injection / trust boundary risk` (high): plan markdown can contain instructions that alter assistant behavior. Injected content must be treated as untrusted context, not instructions.
3. `Context window pressure` (high): full-plan injection can blow token budget, degrade answer quality, and evict relevant chat history.
4. `Missing permission model` (high): if search indexes plans globally, users may surface/inject plans they shouldn't access.
5. `Index freshness + source of truth` (medium): stage (`next/active/done`) can drift unless tied to a canonical parser/index pipeline with clear refresh triggers.
6. `No UX controls for accidental injection` (medium): tapping should likely preview, allow partial insert, and support undo/remove.

**Improvements to the Plan**
1. Lock behavior: choose one default (`attach as hidden context` vs `insert into composer`) and define fallback.
2. Add context strategy: inject structured summary by default, "expand full plan" on demand.
3. Add safety layer: wrap injected plan in a clearly delimited `source document` block.
4. Add UX details: preview modal, section-level injection, chips for attached plans, one-click detach.

**Suggested Minimal v1 Scope**
1. Index plan files with stage metadata.
2. Tap opens preview with "Attach summary" (default) and "Attach full."
3. Attach as hidden, labeled context block (not raw composer paste).
4. Token cap + truncation with link back to source.
