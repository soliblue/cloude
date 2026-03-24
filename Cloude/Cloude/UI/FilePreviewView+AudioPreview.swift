// FilePreviewView+AudioPreview.swift

import SwiftUI
import AVFoundation

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
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)

            Text(fileName)
                .font(.subheadline.weight(.semibold))

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
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 280)

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
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
