import QuickLook
import SwiftUI

struct ChatAttachmentThumbnail: View {
    let data: Data
    @State private var image: CGImage?
    @State private var previewURL: URL?
    @State private var preparingPreview = false
    @State private var failed = false

    var body: some View {
        Button {
            preparingPreview = true
            Task {
                previewURL = await ChatAttachmentService.previewFile(data)
                preparingPreview = false
            }
        } label: {
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else if failed {
                    Image(systemName: "photo.badge.exclamationmark")
                } else {
                    ProgressView()
                }
            }
            .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
        }
        .buttonStyle(.plain)
        .disabled(preparingPreview || failed)
        .accessibilityLabel("Open image attachment")
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { old, new in
            if let old, old != new {
                Task { await ChatAttachmentService.removePreview(old) }
            }
        }
        .task(id: data) {
            image = await ChatAttachmentService.thumbnail(data)
            failed = image == nil
        }
    }
}
