import SwiftUI

struct ChatRemoteStatusRow: View {
    let session: Session
    @State private var control = ChatRemoteControlStore.shared
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                if session.remoteIsRunning { ProgressView().controlSize(.mini) }
                Text(
                    session.remoteIsRunning
                        ? (control.requested.contains(session.id)
                            ? "Stop requested; waiting for remote confirmation" : "Agent working on remote machine")
                        : (session.remoteTurnStatus == "interrupted"
                            ? "Stopped on remote machine" : "Remote conversation")
                )
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if session.remoteIsRunning && session.provider == .codex {
                    Button("Stop", systemImage: "stop.fill") { ChatService.abort(session: session, context: context) }
                        .font(.caption)
                        .disabled(control.submitting.contains(session.id))
                        .accessibilityLabel("Stop agent on remote machine")
                }
                Button {
                    Task { await SessionRemoteFollowService.refresh(session: session, context: context) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh remote conversation")
            }
            if let error = control.errors[session.id] { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .onChange(of: session.remoteIsRunning) { _, running in
            if !running { control.clear(sessionId: session.id) }
        }
    }
}
