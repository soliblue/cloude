# Afto Codex history paging contract

Capability: codexHistoryPages. Both daemons and the incremental iOS importer are implemented on the development branch. Hosts without the capability retain the full-history path.

- GET /codex/threads/:nativeId?includeTurns=false
- GET /sessions/:sessionId/history?includeTurns=false
- POST /sessions/:sessionId/import {"threadId":"nativeId","includeTurns":false}

Omitting includeTurns preserves the existing full-history response. GET accepts exactly true/false strings; POST accepts a boolean. Import still returns {sessionId,threadId,thread} and durably saves the native mapping. Metadata history reads retain ETag/304 behavior. No resume, inference or subscription quota request is performed.

GET /sessions/:sessionId/turns?limit=25&sortDirection=desc&cursor=...

Allowed query fields: cursor, limit, sortDirection. Limit is 1..50 (default 25), direction asc|desc (default desc), cursor opaque nonblank control-free string up to 4096 characters. The server always requests itemsView:"full". Unknown query fields, including itemsView, return 400.

Response 200: {threadId,data:[nativeTurn...],nextCursor:string|null,backwardsCursor:string|null}. All turn payloads have complete items; explicitly summary/notLoaded responses fail 502. Missing itemsView uses official defaultfull for older servers. Duplicate turn IDs, invalid statuses/cursors, or a response larger than the requested turn count fail 502. Native RPC errors return sanitized actionable 502.

threadId is resolved once from the local mapping or input ID. If that mapping changes before completion, history and paging return 409 instead of serving a stale identity. Read-only pages do not reserve or resume a task. Router bearer authentication remains required.

Use the independent descending initial page's nextCursor for older history. The official backwardsCursor used with reversed direction includes its anchor again; upsert by stable turn/item ID and do not confuse live-head continuation with the older-history cursor. Save cursors only with successfully committed page data. Older pages must not set task running status. Metadata remains authoritative for title/status. An item-count page does not bound a single enormous turn's bytes.

Existing fork response and durable receipt snapshot remain full-history and unchanged.

The phone initially imports the latest 25 turns and requests older pages explicitly. Turn records retain server order independently of timestamps and UUIDs, including turns with no visible items. Existing cached histories perform one full migration before switching to pages. Each page and its cursors save together; failed writes roll back only after pending user edits have been flushed. A dropped catch-up request resumes from the last committed cursor. Saved images and message IDs survive overlapping pages.

Initial import uses a private context for new records and the existing main-context endpoint for transport, so response capability updates cannot overwrite host edits through a stale private model. Concurrent imports recheck the saved endpoint/thread mapping before publishing a new local chat.

Deterministic SwiftData tests cover migration retry, cancellation, credential changes, overlapping items, empty turns, image preservation, atomic publication and concurrent opens. Simulator verified 25 initial turns (75 messages, 82,310-byte page) from a synthetic 500-turn history (1,614,696 bytes), then 25 older turns, followed by offline cold-relaunch retention. Show earlier messages explicitly opens the beginning of the newly revealed page, with newer messages still reachable below. This replaces fragile attempts to preserve the old pixel offset while prepending. Large native-history and physical-device performance remain unverified.

Final Simulator check at source 3b928833: Show earlier messages opened cached turn 0450 at the top, then fetched a descending page and opened turn 0425 at the top. SwiftData held 75 turns and 225 messages, older cursor cursor:424 and newer cursor cursor:499. The UI remained responsive during repeated scrolling. After stopping the fixture and cold relaunching, the latest completed response remained visible offline.
