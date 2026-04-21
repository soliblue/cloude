import ImageIO
import SwiftUI
import UIKit

struct FilePreviewGIF: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count = CGImageSourceGetCount(source)
            var frames: [UIImage] = []
            var duration: Double = 0
            for i in 0..<count {
                if let cg = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    frames.append(UIImage(cgImage: cg))
                }
                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
                    let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                {
                    let delay =
                        (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                        ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
                        ?? 0.1
                    duration += delay
                }
            }
            view.animationImages = frames
            view.animationDuration = duration > 0 ? duration : Double(frames.count) * 0.1
            view.image = frames.first
            view.startAnimating()
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
