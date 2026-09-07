import SwiftUI

struct TerminalSheet: View {
    let session: Session
    @State private var store = TerminalStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                if let terminal = store.selected {
                    TerminalConsole(session: session, terminal: terminal).id(terminal.snapshot.id)
                } else {
                    Form {
                        Section("Remote machine") {
                            LabeledContent("Host", value: session.endpoint?.displayName ?? "Remote host")
                            Text(session.path ?? "").font(.caption.monospaced()).textSelection(.enabled)
                        }
                        if !store.terminals.isEmpty {
                            Section("Terminals for this task") {
                                ForEach(store.terminals) { terminal in
                                    Button {
                                        TerminalService.select(terminal, session: session, store: store)
                                    } label: {
                                        HStack {
                                            Label("Shell · \(terminal.label)", systemImage: "terminal")
                                            Spacer()
                                            Text(terminal.status.capitalized).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        Section {
                            Button {
                                Task { await TerminalService.start(session: session, store: store) }
                            } label: {
                                if store.isStarting {
                                    ProgressView("Starting…")
                                } else {
                                    Label("Start terminal with full access", systemImage: "terminal")
                                }
                            }.disabled(store.isStarting || !session.isConfigured)
                        } footer: {
                            Text(
                                "Starts an interactive shell on \(session.endpoint?.displayName ?? "your remote machine") in the folder above, outside the agent sandbox. Commands have full host access. No model is called. Closing this screen leaves it running. Up to four terminals can run on a host; restarting the host daemon ends them."
                            )
                        }
                        if let error = store.error { Text(error).foregroundStyle(.red) }
                        if store.isLoading { ProgressView("Loading terminals…") }
                        Button("Refresh terminals", systemImage: "arrow.clockwise") {
                            Task { await TerminalService.load(session: session, store: store) }
                        }.disabled(store.isLoading)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.palette.background)
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.selected != nil {
                        Button("Terminals", systemImage: "chevron.left") {
                            store.selected = nil
                            Task { await TerminalService.load(session: session, store: store) }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task(id: session.connectionKey) { await TerminalService.load(session: session, store: store) }
        }
        .presentationDetents([.large])
    }
}
