import SwiftUI
import UIKit

struct FilePreviewImage: View {
    let data: Data
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1

    var body: some View {
        if let image = UIImage(data: data) {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width * scale)
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
            }
        } else {
            Text("Invalid image")
                .appFont(size: ThemeTokens.Text.m)
                .foregroundColor(.secondary)
        }
    }
}
