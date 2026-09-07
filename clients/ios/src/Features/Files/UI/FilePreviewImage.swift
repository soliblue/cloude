import SwiftUI
import UIKit

struct FilePreviewImage: View {
    let data: Data
    @State private var image: UIImage?
    @State private var loaded = false
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1

    var body: some View {
        Group {
            if let image {
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
            } else if loaded {
                Text("Invalid image")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(ThemeColor.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: data) {
            loaded = false
            image = await FileImageService.thumbnail(data)
            loaded = true
        }
    }
}
