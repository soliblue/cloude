#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{HistoryPage,HistoryTurn,HistoryTurnRecord,HistoryPageDirection,HistoryImage,HistoryImageService,ImageGeneration,Actions,Message,Reference,ReviewKind,ReviewTarget,ToolResult,Goal,Provider,ToolCall,FileChange,GitChange,ToolKind,BashCommand,TodoItem,WebSource,AgentActivity,StreamEvent,Interaction,InteractionQuestion}.swift \
  src/Features/Files/Logic/FileCache.swift \
  src/Features/Git/Logic/Git{ChangeType,StatusDTO}.swift \
  src/Features/Sessions/Logic/SessionRemote{FollowService,Thread,ThreadKey}.swift \
  tests/remote-history/*.swift -o "$test_dir/remote-history-tests"
"$test_dir/remote-history-tests"
