import SwiftData
import SwiftUI

struct SessionEmptyViewFolderRow: View {
    let session: Session
    @Binding var folderSheetEndpoint: Endpoint?

    var body: some View {
        Button {
            if let endpoint = session.endpoint {
                folderSheetEndpoint = endpoint
            }
        } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: "folder")
                    .appFont(size: ThemeTokens.Text.l)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Path")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                    Text(label)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(session.endpoint == nil)
    }

    private var label: String {
        if let path = session.path, !path.isEmpty { return path }
        return "Choose path"
    }
}
