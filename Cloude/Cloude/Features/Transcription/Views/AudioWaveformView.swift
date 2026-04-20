import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float
    let barCount: Int
    let color: Color
    let barWidth: CGFloat
    let maxHeight: CGFloat

    @State private var barHeights: [CGFloat]

    init(audioLevel: Float, barCount: Int = 7, color: Color = .white, barWidth: CGFloat = DS.Spacing.xs, maxHeight: CGFloat = DS.Size.m) {
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
        .frame(height: maxHeight)
        .onChange(of: audioLevel) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        let baseHeight = CGFloat(level)
        withAnimation(.easeOut(duration: DS.Duration.s)) {
            for i in 0..<barCount {
                let variance = CGFloat.random(in: 0.5...1.5)
                let centerBias = 1.0 - abs(CGFloat(i) - CGFloat(barCount - 1) / 2) / CGFloat(barCount) * 0.6
                barHeights[i] = max(0.15, min(1.0, baseHeight * variance * centerBias))
            }
        }
    }
}
