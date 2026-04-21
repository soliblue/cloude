import SwiftUI

struct ChatAttachmentThumbnail: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.s))
        }
    }
}
