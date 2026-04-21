import AVFoundation
import Combine
import SwiftUI

struct FilePreviewAudio: View {
    let data: Data
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.l) {
            Image(systemName: "waveform")
                .appFont(size: ThemeTokens.Icon.l)
                .foregroundColor(.secondary)
            Slider(value: $progress, in: 0...max(duration, 0.01)) { editing in
                if !editing { player?.currentTime = progress }
            }
            Button {
                if isPlaying {
                    player?.pause()
                } else {
                    player?.play()
                }
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .appFont(size: ThemeTokens.Icon.l)
            }
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            player = try? AVAudioPlayer(data: data)
            duration = player?.duration ?? 0
        }
        .onReceive(timer) { _ in
            if isPlaying, let p = player {
                progress = p.currentTime
                if !p.isPlaying { isPlaying = false }
            }
        }
    }
}
