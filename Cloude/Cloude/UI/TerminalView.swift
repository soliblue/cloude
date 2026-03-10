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
        let isCommand: Bool
        let isError: Bool
    }

    var workingDirectory: String {
        rootPath ?? connection.defaultWorkingDirectory ?? "~"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(outputLines) { line in
                            Text(line.text)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(line.isCommand ? .accentColor : line.isError ? .red : .primary)
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: outputLines.count) {
                    if let last = outputLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

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
                } else {
                    Button(action: executeCommand) {
                        Image(systemName: "return")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(commandText.isEmpty ? .secondary : .accentColor)
                    }
                    .disabled(commandText.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.oceanSecondary)
        }
        .onReceive(connection.events) { event in
            if case let .terminalOutput(output, exitCode, isError) = event {
                if !output.isEmpty {
                    for line in output.components(separatedBy: "\n") {
                        outputLines.append(TerminalLine(text: line, isCommand: false, isError: isError))
                    }
                }
                if exitCode != nil {
                    isExecuting = false
                }
            }
        }
    }

    private func executeCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        outputLines.append(TerminalLine(text: "$ \(cmd)", isCommand: true, isError: false))
        commandHistory.append(cmd)
        historyIndex = -1
        commandText = ""
        isExecuting = true

        connection.terminalExec(command: cmd, workingDirectory: workingDirectory)
    }
}
