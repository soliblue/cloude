# Afto Codex history paging contract

Capability: codexHistoryPages. Linux implementation is available on the development branch. Native Mac and incremental iOS import are not yet implemented; current phone imports still use the compatible full-history path.

- GET /codex/threads/:nativeId?includeTurns=false
- GET /sessions/:sessionId/history?includeTurns=false
- POST /sessions/:sessionId/import {"threadId":"nativeId","includeTurns":false}

Omitting includeTurns preserves the existing full-history response. GET accepts exactly true/false strings; POST accepts a boolean. Import still returns {sessionId,threadId,thread} and durably saves the native mapping. Metadata history reads retain ETag/304 behavior. No resume, inference or subscription quota request is performed.

GET /sessions/:sessionId/turns?limit=25&sortDirection=desc&cursor=...

Allowed query fields: cursor, limit, sortDirection. Limit is1..50(default25), direction asc|desc(defaultdesc), cursor opaque nonblank control-free string up to4096characters. The server always requests itemsView:"full". Unknown query fields, including itemsView, return400.

Response200: {threadId,data:[nativeTurn...],nextCursor:string|null,backwardsCursor:string|null}. All turn payloads have complete items; explicitly summary/notLoaded responses fail502. Missing itemsView uses official defaultfull for older servers. Duplicate turn IDs, invalid statuses/cursors, or a response larger than the requested turn count fail502. Native RPC errors return sanitized actionable502.

threadId is resolved once from the local mapping or input ID. If that mapping changes before completion, history and paging return409 instead of serving a stale identity. Read-only pages do not reserve or resume a task. Router bearer authentication remains required.

Use the independent descending initial page's nextCursor for older history. The official backwardsCursor used with reversed direction includes its anchor again; upsert by stable turn/itemID and do not confuse live-head continuation with the older-history cursor. Save cursors only with successfully committed page data. Older pages must not set task running status. Metadata remains authoritative for title/status. An item-count page does not bound a single enormous turn's bytes.

Existing fork response and durable receipt snapshot remain full-history and unchanged.
