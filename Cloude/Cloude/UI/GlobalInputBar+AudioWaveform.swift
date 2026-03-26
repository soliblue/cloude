import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float
    let barCount: Int
    let color: Color
    let barWidth: CGFloat
    let maxHeight: CGFloat

    @State private var barHeights: [CGFloat]

    init(audioLevel: Float, barCount: Int = 7, color: Color = .white, barWidth: CGFloat = 4, maxHeight: CGFloat = 32) {
        self.audioLevel = audioLevel
        self.barCount = barCount
        self.color = color
        self.barWidth = barWidth
        self.maxHeight = maxHeight
        self._barHeights = State(initialValue: Array(repeating: 0.2, count: barCount))
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth, height: barHeights[index] * maxHeight)
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        let baseHeight = CGFloat(level)
        withAnimation(.easeOut(duration: DS.Duration.instant)) {
            for i in 0..<barCount {
                let variance = CGFloat.random(in: 0.5...1.5)
                let centerBias = 1.0 - abs(CGFloat(i) - CGFloat(barCount - 1) / 2) / CGFloat(barCount) * 0.6
                barHeights[i] = max(0.15, min(1.0, baseHeight * variance * centerBias))
            }
        }
    }
}

struct RecordingOverlayView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    var isTranscribing: Bool = false
    let onStop: () -> Void

    @State private var pulse = false
    @State private var currentLevel: Float = 0

    var body: some View {
        HStack(spacing: DS.Spacing.l) {
            if isTranscribing {
                ProgressView()
                    .tint(.accentColor)

                Spacer()

                Image(systemName: "waveform")
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.accentColor.opacity(DS.Opacity.half))
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(DS.Opacity.full))
                    .frame(width: DS.Size.dot, height: DS.Size.dot)
                    .scaleEffect(pulse ? 1.3 : 0.9)
                    .opacity(pulse ? 0.9 : 0.5)

                Spacer()

                AudioWaveformView(
                    audioLevel: currentLevel,
                    barCount: 7,
                    color: .accentColor.opacity(DS.Opacity.heavy),
                    barWidth: 5,
                    maxHeight: 28
                )

                Spacer()

                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: DS.Icon.l))
                        .foregroundColor(.accentColor.opacity(DS.Opacity.full))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: DS.Radius.l))
        .padding(.horizontal, DS.Spacing.s)
        .onAppear {
            withAnimation(.easeInOut(duration: DS.Duration.pulse).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                currentLevel = audioRecorder.audioLevel
            }
        }
    }
}
