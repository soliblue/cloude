import SwiftUI

struct ChatViewMessageListRowToolPillSheetFileRow: View {
    let session: Session
    let toolCall: ChatToolCall
    let path: String
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label("File", systemImage: "doc")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundColor(.secondary)
            Button {
                presenter.open(session: session, path: path)
                dismiss()
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: "doc.text")
                        .foregroundColor(toolCall.kind.color)
                    Text((path as NSString).lastPathComponent)
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(.secondary)
                }
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
                .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
            }
            .buttonStyle(.plain)
        }
    }
}
