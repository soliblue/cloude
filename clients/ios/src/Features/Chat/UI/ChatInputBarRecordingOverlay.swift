import SwiftUI

struct ChatInputBarRecordingOverlay: View {
    let level: CGFloat
    let isTranscribing: Bool
    let onStop: () -> Void
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            if isTranscribing {
                ProgressView()
                Text("Transcribing")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            } else {
                Circle()
                    .fill(appAccent.color)
                    .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
                ChatInputBarRecordingWaveform(level: level)
                Spacer(minLength: 0)
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(appAccent.color)
                        .padding(ThemeTokens.Spacing.m)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
    }
}

struct ChatInputBarRecordingWaveform: View {
    let level: CGFloat
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(appAccent.color.opacity(ThemeTokens.Opacity.l))
                    .frame(width: 3, height: height(for: index))
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func height(for index: Int) -> CGFloat {
        let bias = 1 - abs(CGFloat(index) - 3) / 4
        return 4 + level * 22 * bias
    }
}
