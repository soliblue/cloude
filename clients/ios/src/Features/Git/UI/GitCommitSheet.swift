import SwiftData
import SwiftUI

struct GitCommitSheet: View {
    let session: Session
    let fileCount: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var message = ""
    @State private var isCommitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Commit message") {
                    TextField("Describe the change", text: $message, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }
                .listRowBackground(theme.palette.surface)
                Section {
                    Label("\(fileCount) staged files", systemImage: "checkmark.circle")
                    Text("Creates a commit on your host using its Git identity and hooks.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(theme.palette.surface)
                if let error {
                    Section { Text(error).foregroundStyle(ThemeColor.danger) }
                        .listRowBackground(theme.palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Commit changes")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isCommitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isCommitting = true
                            error = await GitMutationService.perform(
                                "commit", session: session, message: message, context: context)
                            isCommitting = false
                            if error == nil { dismiss() }
                        }
                    } label: {
                        if isCommitting { ProgressView() } else { Text("Commit") }
                    }
                    .disabled(isCommitting || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(isCommitting)
        .presentationBackground(theme.palette.background)
    }
}
