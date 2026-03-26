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
            HStack(spacing: DS.Spacing.s) {
                ForEach(images) { image in
                    ImageAttachmentPill(
                        imageData: image.data,
                        isScreenshot: image.isScreenshot,
                        onRemove: { onRemove(image.id) }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
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
                    .frame(width: DS.Size.tap, height: DS.Size.tap)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m)
                            .stroke(Color.white.opacity(DS.Opacity.light), lineWidth: DS.Stroke.regular)
                    )
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.Icon.m))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(DS.Opacity.half)).frame(width: DS.Size.glyph, height: DS.Size.glyph))
            }
            .offset(x: 4, y: -4)

            if isScreenshot {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: DS.Text.s, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(DS.Spacing.xs)
                    .background(Circle().fill(Color.black.opacity(DS.Opacity.half)))
                    .offset(x: -2, y: 32)
            }
        }
    }
}
