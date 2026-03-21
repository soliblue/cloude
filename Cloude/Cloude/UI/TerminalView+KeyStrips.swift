import SwiftUI

extension TerminalView {
    var historyStrip: some View {
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
                            .background(Color.themeSecondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.themeBackground)
    }

    var keyStrip: some View {
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
                            .background(label == "ctrl" && ctrlActive ? Color.accentColor.opacity(0.2) : Color.themeSecondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.themeBackground)
    }

    func sendKeySequence(_ sequence: String) {
        if ctrlActive && sequence.count == 1, let ascii = sequence.first?.asciiValue {
            ctrlActive = false
            let ctrlChar = String(UnicodeScalar(ascii & 0x1F))
            connection.terminalInput(text: ctrlChar, terminalId: terminalId, environmentId: environmentId)
        } else {
            connection.terminalInput(text: sequence, terminalId: terminalId, environmentId: environmentId)
        }
    }
}
