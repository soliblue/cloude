import SwiftData
import SwiftUI

struct ChatInputBarMetaRow: View {
    let sessionId: UUID
    let model: ChatModel?
    let effort: ChatEffort?
    let permissionMode: ChatPermissionMode
    let contextTokens: Int
    let contextWindow: Int
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context
    @State private var showContextDetail = false

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
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if contextTokens > 0 && contextWindow > 0 {
                contextRing
            }
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
            .overlay {
                ChatInputBarModelMenuButton(
                    model: model,
                    effort: effort,
                    onModel: { SessionActions.setModel($0, for: sessionId, context: context) },
                    onEffort: { SessionActions.setEffort($0, for: sessionId, context: context) }
                )
            }
        }
    }

    private var contextRing: some View {
        Button {
            showContextDetail.toggle()
        } label: {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showContextDetail) {
            Text("\(Int(((1 - usedFraction) * 100).rounded()))% left (\(tokensK(contextTokens)) used / \(tokensK(contextWindow)))")
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func tokensK(_ tokens: Int) -> String {
        "\(Int((Double(tokens) / 1000).rounded()))K"
    }

    private var usedFraction: Double {
        min(Double(contextTokens) / Double(contextWindow), 1)
    }

    private var ringColor: Color {
        usedFraction > 0.8 ? ThemeColor.danger : appAccent.color
    }
}
