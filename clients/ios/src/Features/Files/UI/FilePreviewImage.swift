import SwiftUI
import UIKit

struct FilePreviewImage: View {
    let data: Data
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1

    var body: some View {
        if let image = UIImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, min(committedScale * value, 6))
                            }
                            .onEnded { _ in
                                committedScale = scale
                            }
                    )
            }
            .scrollIndicators(.hidden)
        } else {
            Text("Invalid image")
                .appFont(size: ThemeTokens.Text.m)
                .foregroundColor(.secondary)
        }
    }
}
