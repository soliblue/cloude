# Agent Consistent Logging

Replace remaining `print` statements with `Log` across agent services. Logger infrastructure already exists — this is the cleanup pass to use it everywhere consistently.

**Files:** `WebSocketServer+HTTP.swift`, `Logger.swift`, and any other files still using `print()`
