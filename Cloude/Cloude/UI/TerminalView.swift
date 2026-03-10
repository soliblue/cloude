import SwiftUI
import Combine
import SwiftTerm
import CloudeShared

struct TerminalView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?
    var environmentId: UUID?
    var terminalId: String?

    @StateObject private var bridge = TerminalBridge()
    @State private var commandText = ""
    @State private var isExecuting = false
    @State private var hasContent = false
    @State private var commandHistory: [String] = []
    @FocusState private var isFocused: Bool

    private let quickCommands = [
        ("ls --color", "folder"),
        ("pwd", "location"),
        ("git status", "point.3.connected.trianglepath.dotted"),
        ("git log --oneline -10", "clock"),
        ("df -h", "internaldrive"),
        ("top -bn1 | head -20", "cpu"),
        ("free -h", "memorychip"),
    ]

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

                if let code = exitCode {
                    isExecuting = false
                    let color = code == 0 ? "32" : "31"
                    bridge.feed("\r\n\u{1B}[\(color)m[exit \(code)]\u{1B}[0m\r\n")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))

            Text(workingDirectory)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCommands, id: \.0) { cmd, icon in
                        Button {
                            commandText = cmd
                            executeCommand()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                Text(cmd)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.oceanSecondary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.oceanBackground)
    }

    private var historyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(commandHistory.suffix(10).reversed().enumerated()), id: \.offset) { _, cmd in
                    Button {
                        commandText = cmd
                    } label: {
                        Text(cmd)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.oceanSecondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.oceanBackground)
    }

    private let terminalKeys: [(String, String)] = [
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

    @State private var ctrlActive = false

    private var keyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(terminalKeys, id: \.0) { label, sequence in
                    Button {
                        if label == "ctrl" {
                            ctrlActive.toggle()
                        } else if ctrlActive && sequence.isEmpty == false {
                            ctrlActive = false
                            sendKeySequence(sequence)
                        } else {
                            sendKeySequence(sequence)
                        }
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: label == "ctrl" && ctrlActive ? .bold : .medium, design: .monospaced))
                            .foregroundColor(label == "ctrl" && ctrlActive ? .accentColor : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(label == "ctrl" && ctrlActive ? Color.accentColor.opacity(0.2) : Color.oceanSecondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.oceanBackground)
    }

    private func sendKeySequence(_ sequence: String) {
        if ctrlActive && sequence.count == 1, let ascii = sequence.first?.asciiValue {
            ctrlActive = false
            let ctrlChar = String(UnicodeScalar(ascii & 0x1F))
            connection.terminalInput(text: ctrlChar, terminalId: terminalId, environmentId: environmentId)
        } else {
            connection.terminalInput(text: sequence, terminalId: terminalId, environmentId: environmentId)
        }
    }

    private var isEnvironmentConnected: Bool {
        if let envId = environmentId {
            return connection.connection(for: envId)?.isAuthenticated ?? false
        }
        return false
    }

    private var canSend: Bool {
        isEnvironmentConnected && (!commandText.isEmpty || isExecuting)
    }

    private var inputBar: some View {
        HStack(spacing: 0) {
            Text(isExecuting ? ">" : "$")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isExecuting ? .green : .accentColor)
                .padding(.leading, 12)

            TextField(isExecuting ? "stdin" : "command", text: $commandText)
                .font(.system(size: 12, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit { isExecuting ? sendInput() : executeCommand() }
                .padding(.horizontal, 8)

            if isExecuting {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            }

            Button(action: { isExecuting ? sendInput() : executeCommand() }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canSend ? .white : .secondary.opacity(0.5))
                    .frame(width: 56)
                    .frame(maxHeight: .infinity)
                    .background(canSend ? Color.accentColor : Color.oceanSecondary.opacity(0.5))
            }
            .disabled(!canSend)
        }
        .frame(height: 44)
        .background(Color.oceanSecondary)
    }

    private func executeCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        hasContent = true
        bridge.feed("\u{1B}[36m$ \(cmd)\u{1B}[0m\r\n")
        if commandHistory.count >= 100 { commandHistory.removeFirst() }
        commandHistory.append(cmd)
        commandText = ""
        isExecuting = true

        connection.terminalExec(command: cmd, workingDirectory: workingDirectory, terminalId: terminalId, environmentId: environmentId)
    }

    private func sendInput() {
        connection.terminalInput(text: commandText + "\n", terminalId: terminalId, environmentId: environmentId)
        commandText = ""
    }

}

class TerminalBridge: ObservableObject {
    var termView: SwiftTerm.TerminalView?

    var onSendBack: ((String) -> Void)?

    func feed(_ text: String) {
        DispatchQueue.main.async {
            self.termView?.feed(text: text)
        }
    }

}

class NoKeyboardTerminalView: SwiftTerm.TerminalView {}

struct SwiftTermWrapper: UIViewRepresentable {
    let bridge: TerminalBridge

    func makeUIView(context: Context) -> NoKeyboardTerminalView {
        let tv = NoKeyboardTerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator
        tv.nativeBackgroundColor = UIColor(Color.oceanBackground)
        tv.nativeForegroundColor = .white
        tv.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.isUserInteractionEnabled = true
        tv.isScrollEnabled = true
        tv.inputView = UIView(frame: .zero)
        tv.inputAccessoryView = nil
        bridge.termView = tv
        return tv
    }

    func updateUIView(_ uiView: NoKeyboardTerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    class Coordinator: NSObject, SwiftTerm.TerminalViewDelegate {
        let bridge: TerminalBridge

        init(bridge: TerminalBridge) {
            self.bridge = bridge
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            let text = String(bytes: data, encoding: .utf8) ?? ""
            if !text.isEmpty {
                bridge.onSendBack?(text)
            }
        }

        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String : String]) {
            if let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        }

        func bell(source: SwiftTerm.TerminalView) {}

        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }

        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}
