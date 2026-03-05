import SwiftUI

struct WordScrambleWidget: View {
    let data: [String: Any]
    @State private var scrambledLetters: [Character] = []
    @State private var selectedIndices: [Int] = []
    @State private var checked = false
    @State private var revealed = false
    @State private var initialized = false

    private var word: String { data["word"] as? String ?? "" }
    private var hint: String? { data["hint"] as? String }
    private var currentAttempt: String { String(selectedIndices.map { scrambledLetters[$0] }) }
    private var isCorrect: Bool { currentAttempt.lowercased() == word.lowercased() }
    private var hasInput: Bool { !selectedIndices.isEmpty }
    private var hasWrong: Bool { checked && !isCorrect }
    private var allPlaced: Bool { selectedIndices.count == word.count }
    private var remainingIndices: [Int] {
        (0..<scrambledLetters.count).filter { !selectedIndices.contains($0) }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "textformat.abc", title: "Word Scramble", color: .yellow) {
                WidgetButton(icon: "arrow.counterclockwise", color: .yellow, enabled: hasInput || checked) {
                    selectedIndices = []
                    checked = false
                    revealed = false
                    scrambledLetters = Array(word).shuffled()
                }
                WidgetButton(icon: "eye", color: .yellow, enabled: hasWrong && !revealed) {
                    selectedIndices = Array(0..<scrambledLetters.count)
                    let correctLetters = Array(word.uppercased())
                    scrambledLetters = correctLetters
                    selectedIndices = Array(0..<correctLetters.count)
                    revealed = true
                    checked = true
                }
                WidgetButton(icon: "checkmark.circle", color: .yellow, enabled: allPlaced && !checked) {
                    checked = true
                }
            }

            if let hint {
                Text(hint)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            FlowLayout(spacing: 6) {
                ForEach(Array(word.enumerated()), id: \.offset) { index, _ in
                    let hasLetter = index < selectedIndices.count
                    let letter = hasLetter ? String(scrambledLetters[selectedIndices[index]]) : ""

                    ZStack {
                        Text(letter)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(checked ? (isCorrect ? .green : .red) : .primary)
                    }
                    .frame(width: 32, height: 38)
                    .background(hasLetter ? Color.yellow.opacity(0.1) : Color.oceanGray6.opacity(0.5))
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(hasLetter ? .yellow.opacity(0.4) : .secondary.opacity(0.3)),
                        alignment: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture {
                        if hasLetter && !checked {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedIndices.remove(at: index)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if !remainingIndices.isEmpty && !checked {
                FlowLayout(spacing: 8) {
                    ForEach(remainingIndices, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedIndices.append(index)
                            }
                        } label: {
                            Text(String(scrambledLetters[index]))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .frame(width: 36, height: 36)
                                .background(Color.oceanGray6.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if checked {
                WidgetResultBadge(isCorrect, correct: "Correct!", wrong: "Not quite")
            }
        }
        .onAppear {
            if !initialized {
                scrambledLetters = Array(word).shuffled()
                initialized = true
            }
        }
    }
}
