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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("Quiz")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedIndex = nil }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(answered ? .cyan : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!answered)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedIndex = correctIndex }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(answered && selectedIndex != correctIndex ? .cyan : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!answered || selectedIndex == correctIndex)
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
                HStack(spacing: 4) {
                    Image(systemName: selectedIndex == correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(selectedIndex == correctIndex ? "Correct!" : "Wrong answer")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
