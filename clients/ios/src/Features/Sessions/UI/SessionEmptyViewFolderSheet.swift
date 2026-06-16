import SwiftData
import SwiftUI

struct SessionEmptyViewFolderSheet: View {
    let session: Session
    let endpoint: Endpoint
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
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
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
        }
        .presentationBackground(theme.palette.background)
    }
}
