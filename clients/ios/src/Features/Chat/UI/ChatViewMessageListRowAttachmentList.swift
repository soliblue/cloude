import SwiftUI

struct ChatViewMessageListRowAttachmentList: View {
    let images: [Data]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(images.indices, id: \.self) { index in
                    ChatAttachmentThumbnail(data: images[index])
                }
            }
        }
        .frame(height: ThemeTokens.Size.l)
    }
}
