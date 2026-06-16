import SwiftUI

struct ChatInputBarTrailingButton: View {
    let sessionId: UUID
    let isStreaming: Bool
    let canSend: Bool
    let canRecord: Bool
    let enabled: Bool
    let model: ChatModel?
    let effort: ChatEffort?
    let onAbort: () -> Void
    let onSend: () -> Void
    let onStartRecording: () -> Void
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        if isStreaming && !canSend {
            Button(action: onAbort) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, appAccent.color)
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        } else if canRecord {
            Image(systemName: "mic.fill")
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(appAccent.color)
                .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .contentShape(Circle())
                .gesture(recordGesture)
        } else {
            Menu {
                ChatInputBarModelMenu(sessionId: sessionId, model: model, effort: effort)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSend ? .white : Color.secondary,
                        canSend ? appAccent.color : Color.secondary.opacity(ThemeTokens.Opacity.s)
                    )
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .contentShape(Circle())
            } primaryAction: {
                onSend()
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let up = -value.translation.height
                let isTap = abs(value.translation.width) < 10 && abs(value.translation.height) < 10
                let isSwipeUp = up >= 50 && up > abs(value.translation.width)
                if canRecord && (isTap || isSwipeUp) { onStartRecording() }
            }
    }
}
