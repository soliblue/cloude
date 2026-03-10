import SwiftUI
import CloudeShared

struct TerminalView: View {
    @ObservedObject var connection: ConnectionManager
    var rootPath: String?

    @State private var commandText = ""
    @State private var outputLines: [TerminalLine] = []
    @State private var isExecuting = false
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @FocusState private var isFocused: Bool

    struct TerminalLine: Identifiable {
        let id = UUID()
        let text: String
        let type: LineType

        enum LineType {
            case command, output, error, directory
        }
    }

    private let quickCommands = [
        ("ls", "folder"),
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
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if outputLines.isEmpty {
                            emptyState
                        }

                        ForEach(outputLines) { line in
                            lineView(line)
                                .id(line.id)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: outputLines.count) {
                    if let last = outputLines.last {
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
                if !output.isEmpty {
                    for line in output.components(separatedBy: "\n") {
                        outputLines.append(TerminalLine(text: line, type: isError ? .error : .output))
                    }
                }
                if exitCode != nil {
                    isExecuting = false
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: TerminalLine) -> some View {
        switch line.type {
        case .command:
            HStack(spacing: 6) {
                Text("$")
                    .foregroundColor(.accentColor)
                    .fontWeight(.bold)
                Text(line.text)
                    .foregroundColor(.accentColor)
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(.top, 8)
        case .error:
            Text(line.text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.red)
                .textSelection(.enabled)
        case .directory:
            Text(line.text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        case .output:
            Text(line.text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
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
                            .background(Color.secondary.opacity(0.1))
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
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.oceanSecondary)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)

            TextField("command", text: $commandText)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit { executeCommand() }
                .disabled(isExecuting)

            if isExecuting {
                ProgressView()
                    .scaleEffect(0.7)
            } else if !outputLines.isEmpty {
                Button(action: clearTerminal) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: executeCommand) {
                Image(systemName: isExecuting ? "stop.fill" : "return")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(commandText.isEmpty && !isExecuting ? .secondary : .accentColor)
            }
            .disabled(commandText.isEmpty && !isExecuting)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.oceanSecondary)
    }

    private func executeCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        outputLines.append(TerminalLine(text: cmd, type: .command))
        commandHistory.append(cmd)
        historyIndex = -1
        commandText = ""
        isExecuting = true

        connection.terminalExec(command: cmd, workingDirectory: workingDirectory)
    }

    private func clearTerminal() {
        outputLines.removeAll()
    }
}
