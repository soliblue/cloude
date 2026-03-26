// MessageBubble+Components.swift

import SwiftUI

struct MessageImageThumbnails: View {
    let message: ChatMessage

    var body: some View {
        if let thumbnails = message.imageThumbnails, thumbnails.count > 1 {
            HStack(spacing: 4) {
                ForEach(thumbnails.indices, id: \.self) { index in
                    if let imageData = Data(base64Encoded: thumbnails[index]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        } else if let imageBase64 = message.imageBase64,
                  let imageData = Data(base64Encoded: imageBase64),
                  let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulse)
            Text("Compacting")
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
        } background: {
            Color.cyan.opacity(0.12)
        }
        .foregroundColor(.cyan)
        .onAppear { pulse = true }
    }
}
