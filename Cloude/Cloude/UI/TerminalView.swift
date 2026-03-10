import SwiftUI
import CloudeShared

struct TerminalView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?

    @State private var commandText = ""
    @State private var commandBlocks: [CommandBlock] = []
    @State private var isExecuting = false
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @FocusState private var isFocused: Bool

    struct CommandBlock: Identifiable {
        let id = UUID()
        let command: String
        var outputSegments: [ANSISegment] = []
        var exitCode: Int?
        var isCollapsed = false

        var isSuccess: Bool { exitCode == 0 }
        var isDone: Bool { exitCode != nil }
    }

    struct ANSISegment: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
        let isBold: Bool
    }

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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if commandBlocks.isEmpty {
                            emptyState
                        }

                        ForEach($commandBlocks) { $block in
                            commandBlockView($block)
                                .id(block.id)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(hex: 0x1A1B26))
                .onChange(of: commandBlocks.count) {
                    if let last = commandBlocks.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            if !commandHistory.isEmpty {
                historyStrip
            }

            inputBar
        }
        .onReceive(connection.events) { event in
            if case let .terminalOutput(output, exitCode, isError) = event {
                guard !commandBlocks.isEmpty else { return }
                let idx = commandBlocks.count - 1

                if !output.isEmpty {
                    let segments = parseANSI(output, isError: isError)
                    commandBlocks[idx].outputSegments.append(contentsOf: segments)
                }

                if let code = exitCode {
                    commandBlocks[idx].exitCode = code
                    isExecuting = false
                }
            }
        }
    }

    @ViewBuilder
    private func commandBlockView(_ block: Binding<CommandBlock>) -> some View {
        let b = block.wrappedValue

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if b.isDone {
                    block.wrappedValue.isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    if b.isDone {
                        Image(systemName: b.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(b.isSuccess ? .green : .red)
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 11, height: 11)
                    }

                    Text("$ \(b.command)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: 0x7AA2F7))

                    Spacer()

                    if b.isDone && !b.outputSegments.isEmpty {
                        Image(systemName: b.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: 0x565F89))
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if !b.isCollapsed && !b.outputSegments.isEmpty {
                FlowTextView(segments: b.outputSegments)
                    .padding(.leading, 17)
                    .padding(.bottom, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: 0x565F89))

            Text(workingDirectory)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: 0x565F89))

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
                            .foregroundColor(Color(hex: 0xA9B1D6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: 0x24283B))
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
                            .foregroundColor(Color(hex: 0xA9B1D6))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0x24283B))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(hex: 0x1A1B26))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: 0x7AA2F7))

            TextField("command", text: $commandText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(hex: 0xA9B1D6))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit { executeCommand() }
                .disabled(isExecuting)

            if isExecuting {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color(hex: 0x7AA2F7))
            } else if !commandBlocks.isEmpty {
                Button(action: clearTerminal) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0x565F89))
                }
                .buttonStyle(.plain)
            }

            Button(action: executeCommand) {
                Image(systemName: "return")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(commandText.isEmpty ? Color(hex: 0x565F89) : Color(hex: 0x7AA2F7))
            }
            .disabled(commandText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0x1A1B26))
    }

    private func executeCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        commandBlocks.append(CommandBlock(command: cmd))
        commandHistory.append(cmd)
        historyIndex = -1
        commandText = ""
        isExecuting = true

        connection.terminalExec(command: cmd, workingDirectory: workingDirectory)
    }

    private func clearTerminal() {
        commandBlocks.removeAll()
    }

    private func parseANSI(_ text: String, isError: Bool) -> [ANSISegment] {
        let defaultColor: Color = isError ? Color(hex: 0xF7768E) : Color(hex: 0xA9B1D6)
        var segments: [ANSISegment] = []
        var currentColor = defaultColor
        var currentBold = false
        var buffer = ""

        let chars = Array(text)
        var i = 0

        while i < chars.count {
            if chars[i] == "\u{1B}" && i + 1 < chars.count && chars[i + 1] == "[" {
                if !buffer.isEmpty {
                    segments.append(ANSISegment(text: buffer, color: currentColor, isBold: currentBold))
                    buffer = ""
                }

                i += 2
                var code = ""
                while i < chars.count && chars[i] != "m" {
                    code.append(chars[i])
                    i += 1
                }
                i += 1

                for part in code.split(separator: ";") {
                    switch Int(part) {
                    case 0: currentColor = defaultColor; currentBold = false
                    case 1: currentBold = true
                    case 30: currentColor = Color(hex: 0x414868)
                    case 31: currentColor = Color(hex: 0xF7768E)
                    case 32: currentColor = Color(hex: 0x9ECE6A)
                    case 33: currentColor = Color(hex: 0xE0AF68)
                    case 34: currentColor = Color(hex: 0x7AA2F7)
                    case 35: currentColor = Color(hex: 0xBB9AF7)
                    case 36: currentColor = Color(hex: 0x7DCFFF)
                    case 37: currentColor = Color(hex: 0xC0CAF5)
                    case 90: currentColor = Color(hex: 0x565F89)
                    case 91: currentColor = Color(hex: 0xF7768E)
                    case 92: currentColor = Color(hex: 0x9ECE6A)
                    case 93: currentColor = Color(hex: 0xE0AF68)
                    case 94: currentColor = Color(hex: 0x7AA2F7)
                    case 95: currentColor = Color(hex: 0xBB9AF7)
                    case 96: currentColor = Color(hex: 0x7DCFFF)
                    case 97: currentColor = Color(hex: 0xC0CAF5)
                    default: break
                    }
                }
            } else {
                buffer.append(chars[i])
                i += 1
            }
        }

        if !buffer.isEmpty {
            segments.append(ANSISegment(text: buffer, color: currentColor, isBold: currentBold))
        }

        return segments
    }
}

struct FlowTextView: View {
    let segments: [TerminalView.ANSISegment]

    var body: some View {
        let lines = buildLines()
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, lineSegments in
                HStack(spacing: 0) {
                    ForEach(lineSegments) { segment in
                        Text(segment.text)
                            .font(.system(size: 13, weight: segment.isBold ? .bold : .regular, design: .monospaced))
                            .foregroundColor(segment.color)
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    private func buildLines() -> [[TerminalView.ANSISegment]] {
        var lines: [[TerminalView.ANSISegment]] = [[]]
        for segment in segments {
            let parts = segment.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, part) in parts.enumerated() {
                if i > 0 { lines.append([]) }
                let text = String(part)
                if !text.isEmpty {
                    lines[lines.count - 1].append(TerminalView.ANSISegment(text: text, color: segment.color, isBold: segment.isBold))
                }
            }
        }
        return lines
    }
}
