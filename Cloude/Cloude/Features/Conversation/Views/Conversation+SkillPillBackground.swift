import SwiftUI

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
