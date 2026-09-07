import SwiftUI

struct SessionCompactionSheet: View {
    let session: Session
    @State private var store = SessionCompactionStore()
    @State private var confirming = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Codex summarizes older context so future turns can use a condensed version. Your saved conversation stays available in Afto."
                    )
                    if session.contextWindow > 0 {
                        LabeledContent(
                            "Context used",
                            value: "\(session.contextTokens.formatted()) / \(session.contextWindow.formatted()) tokens")
                    }
                }
                Section {
                    if store.isPending {
                        ProgressView("Compacting context…")
                        Text("You can close this screen. Compaction continues on the remote machine.").font(.caption)
                            .foregroundStyle(.secondary)
                    } else if store.snapshot?.status == "completed" {
                        Label("Context compacted", systemImage: "checkmark.circle")
                        if store.snapshot?.contextTokens == nil {
                            Text("Updated usage will appear when Codex next reports it.").font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if store.snapshot?.status == "failed" {
                        Label("Compaction did not complete", systemImage: "exclamationmark.circle")
                    }
                    if store.isLoading && !store.isPending {
                        ProgressView(store.isStarting ? "Starting compaction…" : "Checking status…")
                    }
                    if let error = store.error { Text(error).foregroundStyle(.red) }
                    Button("Refresh status") {
                        Task {
                            await SessionCompactionService.refresh(session: session, store: store, context: context)
                        }
                    }
                    .disabled(store.isLoading || store.isStarting)
                    if !store.isPending {
                        Button(store.snapshot?.status == "completed" ? "Compact again" : "Compact context") {
                            confirming = true
                        }
                        .disabled(!store.canStart(session: session))
                    }
                    if session.isStreaming || session.remoteIsRunning {
                        Text("Wait for the current turn to finish before compacting.").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Compact context")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: "\(session.endpoint?.id.uuidString ?? "")|\(session.id)") {
                await SessionCompactionService.refresh(session: session, store: store, context: context)
            }
            .task(id: "\(session.endpoint?.id.uuidString ?? "")|\(session.id)|\(store.isPending)") {
                await SessionCompactionService.poll(session: session, store: store, context: context)
            }
            .onDisappear { store.invalidate() }
            .confirmationDialog("Compact this task’s context?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Compact context") {
                    Task { await SessionCompactionService.start(session: session, store: store, context: context) }
                }
            } message: {
                Text("Older details are summarized for the model. Your saved messages and files stay unchanged.")
            }
        }
    }
}
