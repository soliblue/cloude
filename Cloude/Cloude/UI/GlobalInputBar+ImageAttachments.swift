import SwiftUI
import CloudeShared

struct AttachedImage: Identifiable {
    let id = UUID()
    let data: Data
    let isScreenshot: Bool
}

struct ImageAttachmentStrip: View {
    let images: [AttachedImage]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ImageAttachmentPill(
                        imageData: image.data,
                        isScreenshot: image.isScreenshot,
                        onRemove: { onRemove(image.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct ImageAttachmentPill: View {
    let imageData: Data
    let isScreenshot: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 14, height: 14))
            }
            .offset(x: 4, y: -4)

            if isScreenshot {
                Image(systemName: "camera.viewfinder")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .offset(x: -2, y: 32)
            }
        }
    }
}
