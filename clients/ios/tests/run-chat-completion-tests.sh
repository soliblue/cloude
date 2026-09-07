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
for name in ['closeStream', 'notifyCompletion']:
    start = source.index('    private static func ' + name + '(')
    end = source.index('\n    @MainActor', start)
    methods.append(source[start:end].replace('private static func', 'static func'))
pathlib.Path(sys.argv[1]).write_text('import Foundation\nimport SwiftData\n@MainActor enum ChatService {\nstatic var streamingMessages: [UUID: ChatMessage] = [:]\nstatic var producedOutput: Set<UUID> = []\n' + '\n'.join(methods) + '\n}\n')
PY
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  "$test_dir/ChatService.swift" \
  src/Features/Chat/Logic/Chat{Message,Reference,ReviewKind,ReviewTarget,Provider,Interaction,InteractionQuestion,InteractionStore,AgentAttention}.swift \
  src/Features/Windows/Logic/{Window,SessionToast,SessionToastStore}.swift \
  tests/chat-completion/*.swift -o "$test_dir/chat-completion-tests"
"$test_dir/chat-completion-tests"
