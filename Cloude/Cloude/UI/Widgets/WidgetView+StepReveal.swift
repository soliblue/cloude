import SwiftUI

struct StepRevealWidget: View {
    let data: [String: Any]
    @State private var revealedCount = 0

    private var title: String? { data["title"] as? String }
    private var steps: [String] { data["steps"] as? [String] ?? [] }
    private var allRevealed: Bool { revealedCount >= steps.count }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "list.number", title: title, color: .indigo) {
                WidgetButton(icon: "arrow.counterclockwise", color: .indigo, enabled: revealedCount > 0) {
                    revealedCount = 0
                }
                WidgetButton(icon: "eye", color: .indigo, enabled: !allRevealed) {
                    revealedCount = steps.count
                }
                WidgetButton(icon: "plus.circle", color: .indigo, enabled: !allRevealed) {
                    revealedCount += 1
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(index < revealedCount ? .indigo : .secondary.opacity(0.3))
                            .frame(width: 20)

                        if index < revealedCount {
                            Text(step)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 18)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(10)
                    .background(Color.themeGray6.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            WidgetProgressBadge(
                icon: allRevealed ? "checkmark.circle.fill" : "circle",
                text: "\(revealedCount)/\(steps.count) revealed"
            )
        }
    }
}
