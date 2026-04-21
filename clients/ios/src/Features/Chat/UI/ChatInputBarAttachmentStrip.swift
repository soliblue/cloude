import SwiftUI

struct ChatInputBarAttachmentStrip: View {
    @Binding var images: [Data]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        ChatAttachmentThumbnail(data: data)
                        Button {
                            images.remove(at: index)
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
