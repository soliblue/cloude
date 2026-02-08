# Agent Consistent Logging {text.alignleft}
<!-- priority: 10 -->
<!-- tags: agent -->
<!-- build: 56 -->

> Replace all remaining print() statements with the Log infrastructure across Mac agent services.

Replace remaining `print` statements with `Log` across agent services. Logger infrastructure already exists — this is the cleanup pass to use it everywhere consistently.

**Files:** `WebSocketServer+HTTP.swift`, `Logger.swift`, and any other files still using `print()`
