import SwiftUI

struct QuizWidget: View {
    let data: [String: Any]
    @State private var selectedIndex: Int? = nil

    private var question: String { data["question"] as? String ?? "" }
    private var options: [String] { data["options"] as? [String] ?? [] }
    private var correctIndex: Int { data["correct"] as? Int ?? 0 }
    private var explanation: String? { data["explanation"] as? String }
    private var answered: Bool { selectedIndex != nil }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "questionmark.circle", title: "Quiz", color: .cyan) {
                WidgetButton(icon: "arrow.counterclockwise", color: .cyan, enabled: answered) {
                    selectedIndex = nil
                }
                WidgetButton(icon: "eye", color: .cyan, enabled: answered && selectedIndex != correctIndex) {
                    selectedIndex = correctIndex
                }
            }

            Text(question)
                .font(.system(size: 15, weight: .medium))

            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    optionButton(index: index, text: option)
                }
            }

            if answered, let explanation {
                Text(explanation)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.oceanGray6.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if answered {
                WidgetResultBadge(selectedIndex == correctIndex)
            }
        }
    }

    private func optionButton(index: Int, text: String) -> some View {
        Button {
            if !answered {
                withAnimation(.easeInOut(duration: 0.2)) { selectedIndex = index }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName(index: index))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor(index: index))
                    .frame(width: 20)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(backgroundColor(index: index))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor(index: index), lineWidth: answered && (index == correctIndex || index == selectedIndex) ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private func iconName(index: Int) -> String {
        if !answered { return "circle" }
        if index == correctIndex { return "checkmark.circle.fill" }
        if index == selectedIndex { return "xmark.circle.fill" }
        return "circle"
    }

    private func iconColor(index: Int) -> Color {
        if !answered { return .secondary.opacity(0.4) }
        if index == correctIndex { return .green }
        if index == selectedIndex { return .red }
        return .secondary.opacity(0.3)
    }

    private func backgroundColor(index: Int) -> Color {
        if !answered { return Color.oceanGray6.opacity(0.5) }
        if index == correctIndex { return .green.opacity(0.1) }
        if index == selectedIndex { return .red.opacity(0.1) }
        return Color.oceanGray6.opacity(0.3)
    }

    private func borderColor(index: Int) -> Color {
        if !answered { return .clear }
        if index == correctIndex { return .green.opacity(0.5) }
        if index == selectedIndex { return .red.opacity(0.5) }
        return .clear
    }
}
