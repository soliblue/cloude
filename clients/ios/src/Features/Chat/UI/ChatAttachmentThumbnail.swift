import SwiftUI

struct ChatAttachmentThumbnail: View {
    private let image: UIImage?

    init(data: Data) {
        image = UIImage(data: data)
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
        }
    }
}
