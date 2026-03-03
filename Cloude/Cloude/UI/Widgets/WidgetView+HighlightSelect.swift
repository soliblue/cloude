import SwiftUI

struct HighlightSelectWidget: View {
    let data: [String: Any]
    @State private var selectedWords: Set<String> = []
    @State private var checked = false
    @State private var revealed = false

    private var instruction: String { data["instruction"] as? String ?? "Tap the correct words" }
    private var text: String { data["text"] as? String ?? "" }
    private var correctWords: Set<String> {
        Set((data["correct"] as? [String] ?? []).map { $0.lowercased() })
    }
    private var words: [String] { text.components(separatedBy: " ") }
    private var hasInput: Bool { !selectedWords.isEmpty }
    private var isAllCorrect: Bool { selectedWords == correctWords }
    private var hasWrong: Bool { checked && !isAllCorrect }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "highlighter")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
                Text("Highlight")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWords = []
                            checked = false
                            revealed = false
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasInput || checked ? .yellow : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput && !checked)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWords = correctWords
                            revealed = true
                            checked = true
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong && !revealed ? .yellow : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong || revealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { checked = true }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(checked ? .secondary.opacity(0.3) : .yellow)
                    }
                    .buttonStyle(.plain)
                    .disabled(checked)
                }
            }

            Text(instruction)
                .font(.system(size: 14, weight: .medium))

            FlowLayout(spacing: 4) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    wordButton(word)
                }
            }

            if checked {
                HStack(spacing: 4) {
                    Image(systemName: isAllCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(isAllCorrect ? "All correct!" : "Some selections are wrong")
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

    private func wordButton(_ word: String) -> some View {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let isSelected = selectedWords.contains(cleanWord)
        let isCorrectWord = correctWords.contains(cleanWord)

        return Button {
            if !checked {
                withAnimation(.easeInOut(duration: 0.1)) {
                    if isSelected {
                        selectedWords.remove(cleanWord)
                    } else {
                        _ = selectedWords.insert(cleanWord)
                    }
                }
            }
        } label: {
            Text(word)
                .font(.system(size: 15))
                .foregroundColor(wordColor(isSelected: isSelected, isCorrect: isCorrectWord))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(wordBackground(isSelected: isSelected, isCorrect: isCorrectWord))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(checked)
    }

    private func wordColor(isSelected: Bool, isCorrect: Bool) -> Color {
        if !checked { return isSelected ? .yellow : .primary }
        if isSelected && isCorrect { return .green }
        if isSelected && !isCorrect { return .red }
        if !isSelected && isCorrect { return .orange }
        return .primary
    }

    private func wordBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if !checked { return isSelected ? Color.yellow.opacity(0.2) : .clear }
        if isSelected && isCorrect { return Color.green.opacity(0.15) }
        if isSelected && !isCorrect { return Color.red.opacity(0.15) }
        if !isSelected && isCorrect { return Color.orange.opacity(0.15) }
        return .clear
    }
}
