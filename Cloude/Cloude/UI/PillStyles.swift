import SwiftUI

let skillGradient = LinearGradient(
    colors: [.purple, .pink.opacity(0.8)],
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
        RoundedRectangle(cornerRadius: 14)
            .fill(isSkill ? Color.purple.opacity(0.12) : Color.cyan.opacity(0.12))
            .overlay(
                isSkill ?
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                : nil
            )
    }
}
