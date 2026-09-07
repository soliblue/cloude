import SwiftData
import SwiftUI

struct SessionEmptyViewFolderSheet: View {
    let session: Session
    let endpoint: Endpoint
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if session.provider == .codex && !session.existsOnServer {
                    SessionProjectPicker(session: session, endpoint: endpoint, onPick: { dismiss() })
                } else {
                    FolderPickerView(
                        session: session,
                        endpoint: endpoint,
                        path: "~",
                        title: endpoint.displayName,
                        onPick: { picked in
                            SessionActions.setEndpoint(endpoint, for: session)
                            SessionActions.setPath(picked, for: session)
                            dismiss()
                        }
                    )
                }
            }
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                    .accessibilityLabel("Close project picker")
                }
            }
        }
    }
}
