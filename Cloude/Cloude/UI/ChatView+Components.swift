import SwiftUI

struct StreamingOutput: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Claude is responding...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if !text.isEmpty {
                StreamingMarkdownView(text: text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            Color.accentColor
                .opacity(pulse ? 0.1 : 0.03)
        )
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

struct RunStatsView: View {
    let durationMs: Int
    let costUsd: Double

    var body: some View {
        HStack(spacing: 12) {
            Label(formattedDuration, systemImage: "clock")
            Label(formattedCost, systemImage: "dollarsign.circle")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var formattedDuration: String {
        let seconds = Double(durationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    private var formattedCost: String {
        if costUsd < 0.01 {
            return String(format: "$%.4f", costUsd)
        } else {
            return String(format: "$%.2f", costUsd)
        }
    }
}
