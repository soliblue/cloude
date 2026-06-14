import SwiftUI

struct ChatInputBarMetaRow: View {
    let sessionId: UUID
    let model: ChatModel?
    let effort: ChatEffort?
    let permissionMode: ChatPermissionMode
    let contextTokens: Int
    let contextWindow: Int
    @Environment(\.appAccent) private var appAccent
    @State private var showContextPercent = false

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Spacer()
            Menu {
                ChatInputBarPermissionMenu(sessionId: sessionId, permissionMode: permissionMode)
            } label: {
                Image(systemName: permissionMode.symbol)
                    .font(.system(size: ThemeTokens.Icon.m, weight: .medium))
                    .foregroundStyle(
                        permissionMode == .bypassPermissions ? ThemeColor.danger : Color.secondary
                    )
                    .frame(width: ThemeTokens.Icon.l, height: ThemeTokens.Icon.l)
                    .padding(.vertical, ThemeTokens.Spacing.xs)
                    .padding(.horizontal, ThemeTokens.Spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if contextTokens > 0 && contextWindow > 0 {
                contextRing
            }
            Menu {
                ChatInputBarModelMenu(sessionId: sessionId, model: model, effort: effort)
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Text(model?.displayName ?? "Auto")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundStyle(.secondary)
                    if let effort {
                        ChatInputBarMetaRowEffortBar(fraction: effort.fraction)
                    }
                }
                .padding(.vertical, ThemeTokens.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var contextRing: some View {
        Button {
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                showContextPercent.toggle()
            }
        } label: {
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
                .frame(width: ThemeTokens.Text.m, height: ThemeTokens.Text.m)
                if showContextPercent {
                    Text("\(Int((usedFraction * 100).rounded()))%")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var usedFraction: Double {
        min(Double(contextTokens) / Double(contextWindow), 1)
    }

    private var ringColor: Color {
        usedFraction > 0.8 ? ThemeColor.danger : appAccent.color
    }
}
