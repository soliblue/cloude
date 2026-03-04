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

struct AudioPreview: View {
    let data: Data
    let fileName: String

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)

            Text(fileName)
                .font(.headline)

            if let player = player {
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 280)

                    HStack(spacing: 4) {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 280)

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { setupPlayer() }
        .onDisappear { cleanup() }
    }

    private func setupPlayer() {
        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                progress = player.duration > 0 ? player.currentTime / player.duration : 0
                if !player.isPlaying {
                    isPlaying = false
                    timer?.invalidate()
                }
            }
        }
        isPlaying = player.isPlaying
    }

    private func cleanup() {
        timer?.invalidate()
        player?.stop()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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

