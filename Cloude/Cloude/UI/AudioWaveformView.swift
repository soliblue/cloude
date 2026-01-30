//
//  AudioWaveformView.swift
//  Cloude
//

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
        HStack(spacing: 4) {
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
        withAnimation(.easeOut(duration: 0.08)) {
            for i in 0..<barCount {
                let variance = CGFloat.random(in: 0.5...1.5)
                let centerBias = 1.0 - abs(CGFloat(i) - CGFloat(barCount - 1) / 2) / CGFloat(barCount) * 0.6
                barHeights[i] = max(0.15, min(1.0, baseHeight * variance * centerBias))
            }
        }
    }
}

struct RecordingOverlayView: View {
    let audioLevel: Float
    let onStop: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 1.3 : 0.9)
                .opacity(pulse ? 0.9 : 0.5)

            Spacer()

            AudioWaveformView(
                audioLevel: audioLevel,
                barCount: 7,
                color: .accentColor.opacity(0.7),
                barWidth: 5,
                maxHeight: 28
            )

            Spacer()

            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
