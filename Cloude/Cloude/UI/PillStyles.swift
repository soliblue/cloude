import SwiftUI

struct Pill<Content: View, Background: View>: View {
    let content: Content
    let background: Background

    init(@ViewBuilder content: () -> Content, @ViewBuilder background: () -> Background) {
        self.content = content()
        self.background = background()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            content
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
    }
}

let skillGradient = LinearGradient(
    colors: [.purple, .pink.opacity(DS.Opacity.full)],
    startPoint: .leading,
    endPoint: .trailing
)

let builtInGradient = LinearGradient(
    colors: [.cyan],
    startPoint: .leading,
    endPoint: .trailing
)

struct SkillPillBackground: View {
    let isSkill: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.s)
            .fill(isSkill ? Color.purple.opacity(DS.Opacity.subtle) : Color.cyan.opacity(DS.Opacity.subtle))
            .overlay(
                isSkill ?
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple.opacity(DS.Opacity.strong), Color.pink.opacity(DS.Opacity.medium)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                : nil
            )
    }
}
