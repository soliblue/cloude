import SwiftUI

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
