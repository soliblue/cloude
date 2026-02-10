import SwiftUI
import AVKit
import AVFoundation
import CloudeShared

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

struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BinaryPreview: View {
    let file: FileEntry
    let data: Data

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: file.icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(file.name)
                .font(.headline)

            Text(file.formattedSize)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Binary file - cannot preview")
                .font(.caption)
                .foregroundColor(.secondary)

            ShareLink(item: data, preview: SharePreview(file.name)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
