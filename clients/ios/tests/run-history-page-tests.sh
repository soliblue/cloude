#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{HistoryPage,HistoryTurn,HistoryTurnRecord,HistoryPageDirection,HistoryImage,Actions,PlanActions,Message,Reference,ReviewKind,ReviewTarget,ToolResult,Goal,Provider,ToolCall,FileChange,GitChange,ToolKind,BashCommand,TodoItem,WebSource,AgentActivity,StreamEvent,Interaction,InteractionQuestion}.swift \
  src/Features/Git/Logic/Git{ChangeType,StatusDTO}.swift \
  src/Features/Sessions/Logic/SessionRemote{Thread,ThreadKey}.swift \
  tests/remote-history/{Session,SessionActions,Endpoint}.swift tests/history-pages/*.swift \
  -o "$test_dir/history-page-tests"
"$test_dir/history-page-tests"
