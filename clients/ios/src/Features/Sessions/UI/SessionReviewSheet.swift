import SwiftUI

struct SessionReviewSheet: View {
    let session: Session
    @State private var store = SessionReviewStore()
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Review", selection: $store.kind) {
                        ForEach(ChatReviewKind.allCases) { Text($0.label).tag($0) }
                    }
                    switch store.kind {
                    case .uncommittedChanges:
                        Text("Reviews staged, unstaged and untracked files in this task’s folder.").font(.subheadline)
                            .foregroundStyle(.secondary)
                    case .baseBranch:
                        Picker("Base branch", selection: $store.branches.baseRef) {
                            if store.branches.branches.isEmpty { Text("No branches loaded").tag("") }
                            ForEach(store.branches.branches) { Text($0.name).tag($0.name) }
                        }
                        if store.branches.isLoading { ProgressView("Loading branches…") }
                        if let error = store.branches.error {
                            Text(error).foregroundStyle(.red)
                            Button("Retry loading branches") {
                                Task { await SessionWorktreeService.load(session: session, store: store.branches) }
                            }
                        }
                    case .commit:
                        TextField("Commit SHA", text: $store.sha).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("Enter a full or abbreviated commit hash from this repository.").font(.caption)
                            .foregroundStyle(.secondary)
                    case .custom:
                        TextField("Review instructions", text: $store.instructions, axis: .vertical).lineLimit(4...10)
                    }
                } footer: {
                    Text(
                        "Runs with your host’s Codex review model and subscription. Results stream into this conversation."
                    )
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if session.isStreaming || session.remoteIsRunning {
                    Text("Wait for the current turn to finish before starting a review.").foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Review code")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run review") {
                        if SessionReviewService.run(session: session, store: store, context: context) { dismiss() }
                    }.disabled(!store.canRun(session: session))
                }
            }
            .task(id: store.kind) {
                if store.kind == .baseBranch {
                    await SessionWorktreeService.load(session: session, store: store.branches)
                }
            }
        }
    }
}
