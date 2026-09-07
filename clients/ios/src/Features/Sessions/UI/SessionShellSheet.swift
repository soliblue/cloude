import SwiftUI

struct SessionShellSheet: View {
    let session: Session
    @State private var store = SessionShellStore()
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section("Remote machine") {
                    LabeledContent("Host", value: session.endpoint?.displayName ?? "Remote host")
                    Text(session.path ?? "").font(.caption.monospaced()).textSelection(.enabled)
                }
                Section {
                    SessionShellCommandField(text: $store.command).frame(height: 180)
                } header: {
                    Text("Command")
                } footer: {
                    Text(
                        "Runs directly on \(session.endpoint?.displayName ?? "your remote machine") with full access, outside the agent sandbox. Pipes, redirects and shell syntax are supported. No model is called. Output is saved in this conversation."
                    )
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if session.isStreaming || session.remoteIsRunning {
                    Text("Wait for the current turn to finish before running a command.").foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Run command")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        if SessionShellService.run(session: session, store: store, context: context) { dismiss() }
                    }.disabled(!store.canRun(session: session))
                }
            }
        }
    }
}
