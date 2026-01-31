import SwiftUI
import AVKit
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

struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(.body, design: .monospaced))
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
