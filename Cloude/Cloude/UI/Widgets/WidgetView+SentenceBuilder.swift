import SwiftUI

struct SentenceBuilderWidget: View {
    let data: [String: Any]
    @State private var scrambledWords: [String] = []
    @State private var selectedIndices: [Int] = []
    @State private var checked = false
    @State private var revealed = false
    @State private var initialized = false

    private var sentence: String { data["sentence"] as? String ?? "" }
    private var hint: String? { data["hint"] as? String }
    private var correctWords: [String] { sentence.components(separatedBy: " ") }
    private var currentAttempt: [String] { selectedIndices.map { scrambledWords[$0] } }
    private var isCorrect: Bool { currentAttempt == correctWords }
    private var hasInput: Bool { !selectedIndices.isEmpty }
    private var hasWrong: Bool { checked && !isCorrect }
    private var allPlaced: Bool { selectedIndices.count == scrambledWords.count }
    private var remainingIndices: [Int] {
        (0..<scrambledWords.count).filter { !selectedIndices.contains($0) }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "text.word.spacing", title: "Sentence Builder", color: .green) {
                WidgetButton(icon: "arrow.counterclockwise", color: .green, enabled: hasInput || checked) {
                    selectedIndices = []
                    checked = false
                    revealed = false
                    scrambledWords = correctWords.shuffled()
                }
                WidgetButton(icon: "eye", color: .green, enabled: hasWrong && !revealed) {
                    scrambledWords = correctWords
                    selectedIndices = Array(0..<correctWords.count)
                    revealed = true
                    checked = true
                }
                WidgetButton(icon: "checkmark.circle", color: .green, enabled: allPlaced && !checked) {
                    checked = true
                }
            }

            if let hint {
                Text(hint)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            if !selectedIndices.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(selectedIndices.enumerated()), id: \.offset) { pos, index in
                        Button {
                            if !checked {
                                _ = withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedIndices.remove(at: pos)
                                }
                            }
                        } label: {
                            let word = scrambledWords[index]
                            let correct = checked && pos < correctWords.count && word == correctWords[pos]
                            let wrong = checked && pos < correctWords.count && word != correctWords[pos]

                            Text(word)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(correct ? Color.green.opacity(0.15) : wrong ? Color.red.opacity(0.15) : Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.oceanGray6.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            } else {
                Text("Tap words below to build the sentence")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.oceanGray6.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1, antialiased: true)
                    )
            }

            if !remainingIndices.isEmpty && !checked {
                FlowLayout(spacing: 8) {
                    ForEach(remainingIndices, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedIndices.append(index)
                            }
                        } label: {
                            Text(scrambledWords[index])
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.oceanGray6.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if checked {
                WidgetResultBadge(isCorrect, correct: "Correct!", wrong: "Not quite")
            }
        }
        .onAppear {
            if !initialized {
                scrambledWords = correctWords.shuffled()
                initialized = true
            }
        }
    }
}
