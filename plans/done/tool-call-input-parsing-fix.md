# Tool Call Input Parsing Fix

Tool call detail view assumes JSON input, but agent sends plain strings for Read, Write, Edit, Bash. Fix parsing to handle both string and JSON inputs correctly.

**Files:** `ConnectionManager+API.swift`
