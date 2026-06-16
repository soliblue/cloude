import SwiftUI

struct ChatInputBarAttachmentStrip: View {
    @Binding var images: [ChatImageAttachment]
    @Binding var pastedTexts: [ChatPastedTextAttachment]
    let onInsertPastedText: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(images) { image in
                    ZStack(alignment: .topTrailing) {
                        ChatAttachmentThumbnail(data: image.data)
                        Button {
                            images.removeAll { $0.id == image.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .appFont(size: ThemeTokens.Icon.s)
                                .foregroundStyle(.white, .black.opacity(ThemeTokens.Opacity.l))
                        }
                        .offset(x: ThemeTokens.Spacing.xs, y: -ThemeTokens.Spacing.xs)
                    }
                }
                ForEach(pastedTexts) { pastedText in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            pastedTexts.removeAll { $0.id == pastedText.id }
                            onInsertPastedText(pastedText.text)
                        } label: {
                            ChatAttachmentTextChip(text: pastedText.text)
                        }
                        .buttonStyle(.plain)
                        Button {
                            pastedTexts.removeAll { $0.id == pastedText.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .appFont(size: ThemeTokens.Icon.s)
                                .foregroundStyle(.white, .black.opacity(ThemeTokens.Opacity.l))
                        }
                        .offset(x: ThemeTokens.Spacing.xs, y: -ThemeTokens.Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
        .frame(height: ThemeTokens.Size.l + ThemeTokens.Spacing.s)
    }
}
