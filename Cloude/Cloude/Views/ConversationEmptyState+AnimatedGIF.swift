import SwiftUI
import UIKit
import ImageIO

private enum GIFFrameCache {
    static var cache: [String: (images: [UIImage], duration: Double)] = [:]

    static func frames(for name: String) -> (images: [UIImage], duration: Double)? {
        cache[name]
    }

    static func decode(name: String) -> (images: [UIImage], duration: Double)? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                        ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                        ?? 0.04
                    duration += delay
                }
            }
        }
        let result = (images: images, duration: duration)
        cache[name] = result
        return result
    }
}

struct ConversationEmptyStateAnimatedGIF: UIViewRepresentable {
    let name: String
    let playOnce: Bool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        let repeatCount = playOnce ? 1 : 0
        if let cached = GIFFrameCache.frames(for: name) {
            imageView.animationImages = cached.images
            imageView.animationDuration = cached.duration
            imageView.animationRepeatCount = repeatCount
            imageView.image = cached.images.last
            imageView.startAnimating()
        } else {
            let gifName = name
            Task.detached(priority: .userInitiated) {
                guard let result = GIFFrameCache.decode(name: gifName) else { return }
                await MainActor.run {
                    imageView.animationImages = result.images
                    imageView.animationDuration = result.duration
                    imageView.animationRepeatCount = repeatCount
                    imageView.image = result.images.last
                    imageView.startAnimating()
                }
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
