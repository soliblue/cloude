// MessageBubble+Components.swift

import SwiftUI

struct StatLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .frame(height: 8)
            Text(text)
        }
        .font(.system(size: DS.Text.footnote))
    }
}

struct CompactingIndicator: View {
    @State private var pulse = false

    var body: some View {
        Pill {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: DS.Text.caption, weight: .semibold))
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulse)
            Text("Compacting")
                .font(.system(size: DS.Text.caption, weight: .semibold, design: .monospaced))
        } background: {
            Color.cyan.opacity(0.12)
        }
        .foregroundColor(.cyan)
        .onAppear { pulse = true }
    }
}

struct RunStatsView: View {
    let durationMs: Int
    let costUsd: Double
    var model: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let modelDisplay = modelInfo {
                StatLabel(icon: modelDisplay.icon, text: modelDisplay.name)
            }
            StatLabel(icon: "timer", text: formattedDuration)
            StatLabel(icon: "dollarsign.circle", text: formattedCost)
        }
    }

    private var modelInfo: (name: String, icon: String)? {
        guard let model else { return nil }
        let identity = ModelIdentity(model)
        return (identity.displayName, identity.icon)
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
