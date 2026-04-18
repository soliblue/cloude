import SwiftUI

struct MessageImageThumbnails: View {
    let message: ChatMessage

    var body: some View {
        if let thumbnails = message.imageThumbnails, thumbnails.count > 1 {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(thumbnails.indices, id: \.self) { index in
                    if let imageData = Data(base64Encoded: thumbnails[index]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: DS.Size.l, height: DS.Size.l)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                    }
                }
            }
        } else if let imageBase64 = message.imageBase64,
                  let imageData = Data(base64Encoded: imageBase64),
                  let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: DS.Size.l, height: DS.Size.l)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
        }
    }
}

struct CompactingIndicator: View {
    @State private var pulse = false

    var body: some View {
        Pill {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: DS.Text.s, weight: .semibold))
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: DS.Duration.l).repeatForever(autoreverses: false), value: pulse)
            Text("Compacting")
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
        } background: {
            AppColor.cyan.opacity(DS.Opacity.s)
        }
        .foregroundColor(AppColor.cyan)
        .onAppear { pulse = true }
    }
}
