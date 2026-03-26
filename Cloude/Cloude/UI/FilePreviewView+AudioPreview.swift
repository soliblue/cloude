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
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "waveform")
                .font(.system(size: DS.Icon.l))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)

            Text(fileName)
                .font(.system(size: DS.Text.m, weight: .semibold))

            if let player = player {
                VStack(spacing: DS.Spacing.m) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: DS.Size.chart * 1.4)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(formatTime(player.currentTime))
                            .font(.system(size: DS.Text.s))
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(.system(size: DS.Text.s))
                    }
                    .font(.system(size: DS.Text.s).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: DS.Size.chart * 1.4)

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: DS.Icon.l))
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
