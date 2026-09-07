import SwiftUI

struct SessionRenameSheet: View {
    let session: Session
    @State private var title = ""
    @State private var isSaving = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                TextField("Chat name", text: $title)
                if failed {
                    Text("Could not rename the remote chat. Check your connection and try again.").foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Rename chat")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            if await SessionService.rename(session: session, title: title) {
                                dismiss()
                            } else {
                                failed = true
                            }
                            isSaving = false
                        }
                    }.disabled(
                        isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200)
                }
            }
            .onAppear { title = session.title }
        }
        .presentationDetents([.medium])
    }
}
