import SwiftUI

struct ChatInputBarMetaRow: View {
    let sessionId: UUID
    let model: ChatModel?
    let effort: ChatEffort?
    let contextTokens: Int
    let contextWindow: Int
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Spacer()
            if contextTokens > 0 && contextWindow > 0 {
                contextRing
            }
            Menu {
                ChatInputBarModelMenu(sessionId: sessionId, model: model, effort: effort)
            } label: {
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    Image(systemName: model?.symbol ?? "cpu")
                    Text(pillText)
                }
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .foregroundStyle(.secondary)
                .padding(.vertical, ThemeTokens.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var pillText: String {
        let name = model?.displayName ?? "Auto"
        return effort.map { "\(name) · \($0.displayName)" } ?? name
    }

    private var contextRing: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(ThemeTokens.Opacity.s), lineWidth: ThemeTokens.Stroke.l)
                Circle()
                    .trim(from: 0, to: usedFraction)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: ThemeTokens.Stroke.l, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
            Text("\(Int((usedFraction * 100).rounded()))%")
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var usedFraction: Double {
        min(Double(contextTokens) / Double(contextWindow), 1)
    }

    private var ringColor: Color {
        usedFraction > 0.8 ? ThemeColor.danger : appAccent.color
    }
}
