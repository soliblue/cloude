import SwiftUI

struct ChatRemoteStatusRow: View {
    let session: Session
    @State private var control = ChatRemoteControlStore.shared
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if session.remoteIsRunning || control.errors[session.id] != nil {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    if session.remoteIsRunning {
                        HStack(spacing: ThemeTokens.Spacing.s) {
                            ProgressView().controlSize(.mini)
                            Text(
                                control.requested.contains(session.id)
                                    ? "Stop requested; waiting for remote confirmation"
                                    : "Agent working on remote machine"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if session.provider == .codex {
                                Button("Stop", systemImage: "stop.fill") {
                                    ChatService.abort(session: session, context: context)
                                }
                                .font(.caption)
                                .disabled(control.submitting.contains(session.id))
                                .accessibilityLabel("Stop agent on remote machine")
                            }
                        }
                    }
                    if let error = control.errors[session.id] { Text(error).font(.caption).foregroundStyle(.red) }
                }
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.xs)
            }
        }
        .onChange(of: session.remoteIsRunning) { _, running in
            if !running { control.clear(sessionId: session.id) }
        }
    }
}
