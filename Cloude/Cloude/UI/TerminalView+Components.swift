import SwiftUI

extension TerminalView {
    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "terminal")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.4))

            Text(workingDirectory)
                .font(.footnote.monospaced())
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
                                    .font(.caption2)
                                Text(cmd)
                                    .font(.footnote.monospaced())
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.themeSecondary)
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
        .background(Color.themeBackground)
    }

    var isEnvironmentConnected: Bool {
        if let envId = environmentId {
            return connection.connection(for: envId)?.isAuthenticated ?? false
        }
        return false
    }

    var canSend: Bool {
        isEnvironmentConnected && (!commandText.isEmpty || isExecuting)
    }

    var inputBar: some View {
        HStack(spacing: 0) {
            Text(isExecuting ? ">" : "$")
                .font(.footnote.weight(.bold).monospaced())
                .foregroundColor(isExecuting ? .pastelGreen : .accentColor)
                .padding(.leading, 12)

            TextField(isExecuting ? "stdin" : "command", text: $commandText)
                .font(.footnote.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit { isExecuting ? sendInput() : executeCommand() }
                .padding(.horizontal, 8)

            Button(action: { isExecuting ? sendInput() : executeCommand() }) {
                Image(systemName: "paperplane.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(canSend ? .white : .secondary.opacity(0.5))
                    .frame(width: 56)
                    .frame(maxHeight: .infinity)
                    .background(canSend ? Color.accentColor : Color.themeSecondary.opacity(0.5))
            }
            .disabled(!canSend)
        }
        .frame(height: 44)
        .background(Color.themeSecondary)
    }

    func executeCommand() {
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

    func sendInput() {
        connection.terminalInput(text: commandText + "\n", terminalId: terminalId, environmentId: environmentId)
        commandText = ""
    }
}
