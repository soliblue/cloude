#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
python3 - "$test_dir" <<'PY'
import pathlib
import re
import sys
source = pathlib.Path('src/Features/Chat/Logic/ChatService.swift').read_text()
actions = pathlib.Path('src/Features/Chat/Logic/ChatActions.swift').read_text()
def method(text, name):
    start = re.search(r'    (?:private )?static func '+name+r'\(', text).start()
    return text[start:text.index('\n    @MainActor', start)]
pathlib.Path(sys.argv[1], 'ChatService.swift').write_text('''import Foundation
import SwiftData
@MainActor enum ChatService {
    static var activeStreams: Set<UUID> = []
    static var steeringRequests: Set<UUID> = []
    static var beginnings: [(UUID, Int64, Int, ChatMessage.State)] = []
    static var assistants: [ChatMessage] = []
    static func begin(message: ChatMessage, session: Session, endpoint: Endpoint, path: String, context: ModelContext) {
        beginnings.append((message.id, message.timelineOrder, message.timelineItemOrder, message.state))
        assistants.append(ChatActions.beginAssistant(sessionId: session.id, context: context))
        session.isStreaming = true
    }
    static func drainForTest(sessionId: UUID, context: ModelContext) { drainQueue(sessionId: sessionId, context: context) }
'''+ '\n'.join(method(source, name) for name in ['steer', 'retry', 'drainQueue']) + '\n}\n')
pathlib.Path(sys.argv[1], 'ChatActions.swift').write_text('import Foundation\nimport SwiftData\n@MainActor enum ChatActions {\n' + '\n'.join(method(actions, name) for name in ['nextTimelineOrder', 'beginAssistant']) + '\n}\n')
PY
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  "$test_dir/ChatService.swift" "$test_dir/ChatActions.swift" \
  src/Features/Chat/Logic/Chat{HistoryTurnRecord,Message,Reference,ReviewKind,ReviewTarget,Provider}.swift \
  tests/chat-steer/*.swift -o "$test_dir/steer-tests"
"$test_dir/steer-tests"
"$test_dir/steer-tests" --persist "$test_dir/steering.store"
"$test_dir/steer-tests" --recover "$test_dir/steering.store"
