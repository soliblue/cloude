import SwiftData
import SwiftUI

struct SessionWorktreeSheet: View {
    let session: Session
    @State private var store = SessionWorktreeStore()
    @Query private var windows: [Window]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("New branch name", text: $store.branch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("New worktree branch name")
                    if let error = store.branchError { Text(error).font(.caption).foregroundStyle(.red) }
                    Picker("Start from", selection: $store.baseRef) {
                        if store.branches.isEmpty { Text("No branches loaded").tag("") }
                        ForEach(store.branches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                } footer: {
                    Text(
                        "A new task starts in a separate worktree from the selected committed branch. Uncommitted changes and this conversation stay in the current task."
                    )
                }
                .disabled(store.isCreating)
                if store.isLoading { ProgressView("Loading branches…") }
                if store.isCreating { ProgressView("Creating worktree…") }
                if let error = store.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        if store.branches.isEmpty {
                            Button("Retry loading branches") {
                                Task { await SessionWorktreeService.load(session: session, store: store) }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("New worktree task")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(store.isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if let created = await SessionWorktreeService.create(
                                session: session, store: store, context: context)
                            {
                                WindowActions.open(created, among: windows, context: context)
                                dismiss()
                            }
                        }
                    }.disabled(!store.canCreate)
                }
            }
            .interactiveDismissDisabled(store.isCreating)
            .task { await SessionWorktreeService.load(session: session, store: store) }
        }
    }
}
