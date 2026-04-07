import SwiftUI
import AVKit
import AVFoundation
import PDFKit
import ImageIO

struct GIFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count = CGImageSourceGetCount(source)
            var frames: [UIImage] = []
            var totalDuration: Double = 0

            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    frames.append(UIImage(cgImage: cgImage))
                    if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                            ?? 0.1
                        totalDuration += max(delay, 0.02)
                    } else {
                        totalDuration += 0.1
                    }
                }
            }

            if frames.count > 1 {
                imageView.animationImages = frames
                imageView.animationDuration = totalDuration
                imageView.animationRepeatCount = 0
                imageView.startAnimating()
            } else if let first = frames.first {
                imageView.image = first
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ImagePreview: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width * scale)
                    .scaleEffect(scale)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale = $0 }
                .onEnded { _ in scale = max(1.0, min(scale, 5.0)) }
        )
    }
}

struct VideoPreview: View {
    let data: Data

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try? data.write(to: tempURL)
        player = AVPlayer(url: tempURL)
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
