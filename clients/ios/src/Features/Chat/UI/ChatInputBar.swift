import SwiftUI

struct ChatInputBar: View {
    var onSend: (String, [Data]) -> Void
    @State private var draft: String = ""
    @State private var images: [Data] = []
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.xs) {
            if !images.isEmpty {
                ChatInputBarAttachmentStrip(images: $images)
            }
            HStack(alignment: .center, spacing: ThemeTokens.Spacing.s) {
                ChatInputBarAttachmentPicker(images: $images)
                TextField("Message", text: $draft, axis: .vertical)
                    .appFont(size: ThemeTokens.Text.m)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                Button {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty || !images.isEmpty {
                        onSend(trimmed, images)
                        draft = ""
                        images = []
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .appFont(size: ThemeTokens.Icon.xl)
                        .foregroundColor(canSend ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .background(theme.palette.background)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }
}
