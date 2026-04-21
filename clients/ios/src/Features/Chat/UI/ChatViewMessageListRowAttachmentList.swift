import SwiftUI

struct ChatViewMessageListRowAttachmentList: View {
    let images: [Data]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, data in
                    ChatAttachmentThumbnail(data: data)
                }
            }
        }
        .frame(height: ThemeTokens.Size.l)
    }
}
