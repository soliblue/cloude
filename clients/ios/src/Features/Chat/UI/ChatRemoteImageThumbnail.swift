import SwiftData
import SwiftUI

struct ChatRemoteImageThumbnail: View {
    let source: String
    let message: ChatMessage
    let session: Session
    @Environment(\.modelContext) private var context
    @State private var loading = true
    @State private var attempt = 0

    var body: some View {
        Button {
            attempt += 1
        } label: {
            Group {
                if loading {
                    ProgressView()
                } else {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: ThemeTokens.Icon.m))
                }
            }
            .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
        }
        .buttonStyle(.plain)
        .disabled(loading || !source.hasPrefix("/"))
        .accessibilityLabel(
            loading
                ? "Loading image attachment"
                : source.hasPrefix("/") ? "Image attachment unavailable. Retry" : "Image attachment unavailable"
        )
        .accessibilityHint("The original image is stored on your remote machine.")
        .task(id: "\(session.connectionKey)|\(source)|\(attempt)") {
            loading = true
            _ = await ChatHistoryImageService.load(source: source, message: message, session: session, context: context)
            loading = false
        }
    }
}
