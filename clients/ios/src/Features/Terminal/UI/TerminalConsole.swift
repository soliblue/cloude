import SwiftUI

struct TerminalConsole: View {
    let session: Session
    let terminal: TerminalSessionStore
    @State private var confirmingTerminate = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.endpoint?.displayName ?? "Remote host").font(.caption.weight(.semibold))
                Text(terminal.snapshot.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                HStack {
                    Text(
                        terminal.snapshot.isRunning
                            ? (terminal.connected ? "Connected · Full access" : "Disconnected · Input paused")
                            : "\(terminal.snapshot.status.capitalized)\(terminal.snapshot.exitCode.map { " (\($0))" } ?? "")"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if terminal.snapshot.isRunning {
                        Button("Terminate", role: .destructive) { confirmingTerminate = true }
                            .font(.caption).disabled(terminal.terminating)
                    }
                }
                if let gap = terminal.gap { Text(gap).font(.caption).foregroundStyle(.orange) }
                if let error = terminal.error ?? terminal.snapshot.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let inputError = terminal.inputError {
                    HStack {
                        Text(inputError).font(.caption).foregroundStyle(.red)
                        Button("Retry input") { TerminalService.retryInput(session: session, terminal: terminal) }
                            .font(.caption).disabled(!terminal.connected)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal).padding(.vertical, 8)
            TerminalSurface(terminal: terminal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            TerminalControls(terminal: terminal).background(theme.palette.background)
        }
        .task(id: "\(session.connectionKey)|\(terminal.snapshot.id)|\(scenePhase)") {
            if scenePhase == .active { await TerminalService.follow(session: session, terminal: terminal) }
        }
        .confirmationDialog("Terminate this terminal?", isPresented: $confirmingTerminate, titleVisibility: .visible) {
            Button("Terminate", role: .destructive) {
                Task { await TerminalService.terminate(session: session, terminal: terminal) }
            }
        } message: {
            Text("Ends this remote shell and its running work. Closing this screen leaves the terminal running.")
        }
    }
}
