#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
python3 - "$test_dir/ChatService.swift" <<'PY'
import pathlib
import sys
source = pathlib.Path('src/Features/Chat/Logic/ChatService.swift').read_text()
methods = []
for name in ['checkpointLastSeq', 'ensureStreamingMessage', 'existingStreamMessage']:
    start = source.index('    private static func '+name+'(')
    end = source.index('\n    @MainActor', start)
    methods.append(('    @discardableResult\n' if name == 'checkpointLastSeq' else '') + source[start:end].replace('private static func', 'static func'))
start = source.index('        case .assistantTextDelta(')
end = source.index('        case .toolOutputDelta(', start)
replay = source.index('        case .replay:', end)
replay_end = source.index('        case .initialized', replay)
reset = source.index('        if !checkpointLastSeq(sessionId: session.id, seq: -1, context: context, reset: true)')
reset_end = source.index('        SessionActions.setRemoteFollowing', reset)
pathlib.Path(sys.argv[1]).write_text('''import Foundation
import SwiftData
@MainActor enum ChatService {
    static var streamingMessages: [UUID: ChatMessage] = [:]
    static var producedOutput: Set<UUID> = []
    static var activeModels: [UUID: String] = [:]
    static func startNewTurn(session: Session, message: ChatMessage, context: ModelContext) {
'''+source[reset:reset_end]+'''    }
'''+ '\n'.join(methods)+'''
    static func apply(event: ChatStreamEvent, sessionId: UUID, context: ModelContext) {
        switch event {
'''+source[start:end]+source[replay:replay_end]+'''        default: break
        }
    }
}
''')
PY
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  "$test_dir/ChatService.swift" \
  src/Features/Chat/Logic/Chat{HistoryPage,HistoryTurn,HistoryTurnRecord,HistoryPageDirection,HistoryImage,Actions,PlanActions,Message,Reference,ReviewKind,ReviewTarget,ToolResult,Goal,Provider,ToolCall,FileChange,GitChange,ToolKind,BashCommand,TodoItem,WebSource,AgentActivity,StreamEvent,Interaction,InteractionQuestion,LiveStream,LiveSnapshot}.swift \
  src/Features/Git/Logic/Git{ChangeType,StatusDTO}.swift \
  src/Features/Sessions/Logic/SessionRemote{Thread,ThreadKey}.swift \
  tests/remote-history/Endpoint.swift tests/chat-replay/*.swift \
  -o "$test_dir/replay-tests"
"$test_dir/replay-tests" write "$test_dir/state.store"
"$test_dir/replay-tests" read "$test_dir/state.store"
