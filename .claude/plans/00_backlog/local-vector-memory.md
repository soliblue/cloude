---
title: "Local Vector Memory (Long-Term Memory Layer)"
description: "Add a semantic long-term memory layer alongside CLAUDE.local.md for colder retrieval."
created_at: 2026-03-13
tags: ["memory"]
icon: cylinder.split.1x2
build: 86
---


# Local Vector Memory (Long-Term Memory Layer)
## Summary
Add a local vector database (sqlite-vec or similar) as a cold storage memory layer alongside the always-on CLAUDE.local.md. Enables semantic search over previous conversations, documents, and archived memories.

## Architecture
- sqlite-vec database stored in `.claude/memory/memory.db`
- Python scripts for embedding (via API) and querying (via bash)
- Two-tier memory: hot (CLAUDE.local.md, always loaded) + cold (vector DB, queried on-demand)

## Use Cases
- Search previous conversation transcripts semantically
- Scale memory beyond CLAUDE.local.md size limits
- Ingest external documents (diary, notes, papers)

## Open Questions
- Chunking strategy: per-message, per-turn, or per-topic?
- When to trigger cold memory queries (session start? mid-conversation?)
- Which embedding model/API to use
- Whether the complexity is worth it vs grep over transcripts

## Status
Idea stage. Needs experimentation to validate value.
