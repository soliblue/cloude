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
    colors: [AppColor.purple, AppColor.pink.opacity(DS.Opacity.l)],
    startPoint: .leading,
    endPoint: .trailing
)

let builtInGradient = LinearGradient(
    colors: [AppColor.cyan],
    startPoint: .leading,
    endPoint: .trailing
)

struct SkillPillBackground: View {
    let isSkill: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.s)
            .fill(isSkill ? AppColor.purple.opacity(DS.Opacity.s) : AppColor.cyan.opacity(DS.Opacity.s))
            .overlay(
                isSkill ?
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .stroke(
                        LinearGradient(
                            colors: [AppColor.purple.opacity(DS.Opacity.m), AppColor.pink.opacity(DS.Opacity.m)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                : nil
            )
    }
}
