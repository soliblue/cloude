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
