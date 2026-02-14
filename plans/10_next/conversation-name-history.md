# Conversation Name History {clock.arrow.trianglehead.counterclockwise.rotate.90}
<!-- priority: 2 -->
<!-- tags: ui, search, metadata -->

> Track previous conversation names so renamed conversations are still findable.

## Problem

Conversations get renamed as topics shift. Once renamed, the old name is lost — makes it hard to find conversations you remember by their earlier name.

## Design Decision

Old names are NOT shown in the main UI — they only surface in search results. When a search matches an old name, show it as secondary text under the current name.

## Plan

- Store name history array in conversation metadata (every `cloude rename` appends to history)
- Old names only visible in search results (no UI clutter elsewhere)
- Make old names searchable (feeds into conversation search feature)

## Files
- `Cloude Agent/` — persist name history when processing `cloude rename`
- `CloudeShared/` — add `previousNames: [String]?` to conversation model

## Codex Review

**Findings (highest risk first)**

1. **Data model change is underspecified** — `previousNames: [String]?` is ambiguous for migration and query behavior. Risk: `nil` vs `[]` inconsistency. Improve: prefer non-optional `previousNames: [String] = []` and define migration for existing records.
2. **Unbounded history can grow without limits** — repeated renames can bloat metadata and search index. Improve: cap history (e.g. last 20), dedupe consecutive duplicates, trim whitespace, normalize case.
3. **Search relevance/ranking behavior is missing** — if old-name matches are treated equal to current name matches, search quality may degrade. Improve: rank current-name hits above old-name hits; show matched old name snippet as secondary text only when that field matched.
4. **No conflict/consistency strategy for concurrent renames** — multi-device or retry scenarios can produce duplicate or out-of-order history. Improve: make rename append idempotent (event id/timestamp), and define ordering rules.
5. **Privacy/compliance retention not addressed** — old names may contain sensitive terms users expect to disappear after rename. Improve: define retention policy, delete behavior, and whether "clear history" is needed.
6. **Backfill/index migration plan is missing** — existing conversations won't have searchable old names unless indexed/migrated.

**Open questions**
1. Should initial name ever be included in `previousNames`, or only names replaced by a rename?
2. Should duplicate historical names be kept if a user toggles between two names?
3. Should users be able to remove individual historical names?

**Suggested implementation tweaks**
1. Model: `previousNames: [String]` (non-optional), normalized on write.
2. Rename rule: append old current name only if distinct after normalization.
3. Search: match both fields, but score `currentName > previousNames`.
4. UI: secondary line only when `previousNames` caused the match, with highlight.
