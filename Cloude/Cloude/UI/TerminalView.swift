import SwiftUI
import Combine
import SwiftTerm
import CloudeShared

struct TerminalView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?
    var terminalId: String?

    @StateObject var bridge = TerminalBridge()
    @State var commandText = ""
    @State var isExecuting = false
    @State var hasContent = false
    @State var commandHistory: [String] = []
    @FocusState var isFocused: Bool

    let quickCommands = [
        ("ls --color", "folder"),
        ("pwd", "location"),
        ("git status", "point.3.connected.trianglepath.dotted"),
        ("git log --oneline -10", "clock"),
        ("df -h", "internaldrive"),
        ("top -bn1 | head -20", "cpu"),
        ("free -h", "memorychip"),
    ]

    let terminalKeys: [(String, String)] = [
        ("esc", "\u{1B}"),
        ("ctrl", ""),
        ("tab", "\t"),
        ("↑", "\u{1B}[A"),
        ("↓", "\u{1B}[B"),
        ("→", "\u{1B}[C"),
        ("←", "\u{1B}[D"),
        ("|", "|"),
        ("~", "~"),
        ("/", "/"),
        ("-", "-"),
    ]

    @State var ctrlActive = false

    var workingDirectory: String {
        rootPath ?? connection.defaultWorkingDirectory ?? "~"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SwiftTermWrapper(bridge: bridge)
                    .opacity(hasContent ? 1 : 0)

                if !hasContent {
                    emptyState
                }
            }

            Divider()

            if !commandHistory.isEmpty {
                historyStrip
            }

            if isExecuting {
                keyStrip
            }

            inputBar
        }
        .onAppear {
            bridge.onSendBack = { [weak connection] text in
                connection?.terminalInput(text: text, terminalId: terminalId, environmentId: environmentId)
            }
        }
        .onReceive(connection.events) { event in
            if case let .terminalOutput(output, exitCode, _, tid) = event {
                if tid != nil && tid != terminalId { return }

                if !output.isEmpty {
                    hasContent = true
                    bridge.feed(output)
                }

                if exitCode != nil {
                    isExecuting = false
                }
            }
        }
    }
}
