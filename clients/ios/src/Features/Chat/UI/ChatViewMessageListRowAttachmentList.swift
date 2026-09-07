import SwiftUI

struct ChatViewMessageListRowAttachmentList: View {
    let images: [Data]
    var message: ChatMessage? = nil
    var session: Session? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    if data.isEmpty, let message, let session,
                        let sources = message.imageSources, sources.indices.contains(index)
                    {
                        ChatRemoteImageThumbnail(source: sources[index], message: message, session: session)
                    } else {
                        ChatAttachmentThumbnail(data: data)
                    }
                }
            }
        }
        .frame(height: ThemeTokens.Size.l)
    }
}
