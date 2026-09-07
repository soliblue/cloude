#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{HistoryPage,HistoryTurn,HistoryTurnRecord,HistoryPageDirection,HistoryImage,Actions,Message,Reference,ReviewKind,ReviewTarget,ToolResult,Goal,Provider,ToolCall,FileChange,GitChange,ToolKind,BashCommand,TodoItem,WebSource,AgentActivity,StreamEvent,Interaction,InteractionQuestion,Model,Effort,PermissionMode}.swift \
  src/Features/Git/Logic/Git{ChangeType,StatusDTO}.swift \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionTab.swift \
  src/Features/Sessions/Logic/Session+{ConnectionScope,HistoryScope}.swift \
  src/Features/Sessions/Logic/Session{HistoryPageService,HistoryPageStore,Actions+History,RemoteThread,RemoteThreadKey}.swift \
  tests/remote-history/SessionActions.swift tests/history-page-service/*.swift \
  -o "$test_dir/history-page-service-tests"
"$test_dir/history-page-service-tests"
