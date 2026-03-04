import SwiftUI

struct FillInBlankWidget: View {
    let data: [String: Any]
    @State private var answers: [String] = []
    @State private var checked = false
    @State private var revealed = false
    @State private var originalAnswers: [String] = []
    @FocusState private var focusedBlank: Int?

    private var text: String { data["text"] as? String ?? "" }
    private var blanks: [String] { data["blanks"] as? [String] ?? [] }
    private var hint: String? { data["hint"] as? String }
    private var hasInput: Bool { answers.contains { !$0.isEmpty } }

    private var allCorrect: Bool {
        zip(answers, blanks).allSatisfy { typed, correct in
            typed.trimmingCharacters(in: .whitespaces).lowercased() == correct.lowercased()
        }
    }

    private var hasWrong: Bool { checked && !allCorrect }

    private enum Token: Identifiable {
        case word(String)
        case blank(Int)

        var id: String {
            switch self {
            case .word(let s): return "w:\(s):\(UUID().uuidString.prefix(4))"
            case .blank(let i): return "b:\(i)"
            }
        }
    }

    private var tokens: [Token] {
        var result: [Token] = []
        var remaining = text
        var blankIdx = 0
        while let range = remaining.range(of: "___") {
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            for word in before.split(separator: " ", omittingEmptySubsequences: false) {
                let w = String(word)
                if !w.isEmpty { result.append(.word(w)) }
            }
            result.append(.blank(blankIdx))
            blankIdx += 1
            remaining = String(remaining[range.upperBound...])
        }
        for word in remaining.split(separator: " ", omittingEmptySubsequences: false) {
            let w = String(word)
            if !w.isEmpty { result.append(.word(w)) }
        }
        return result
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "text.badge.checkmark", title: hint, color: .orange) {
                WidgetButton(icon: "arrow.counterclockwise", color: .orange, enabled: hasInput || checked) {
                    answers = Array(repeating: "", count: blanks.count)
                    checked = false
                    revealed = false
                    focusedBlank = nil
                }
                WidgetButton(icon: "eye", color: .orange, enabled: hasWrong && !revealed) {
                    for i in blanks.indices {
                        if !isBlankCorrect(i) { answers[i] = blanks[i] }
                    }
                    revealed = true
                }
                WidgetButton(icon: "checkmark.circle", color: .orange, enabled: !checked) {
                    originalAnswers = answers
                    checked = true
                    focusedBlank = nil
                }
            }

            FlowLayout(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    switch token {
                    case .word(let word):
                        Text(word)
                            .font(.system(size: 15))
                    case .blank(let idx):
                        if idx < blanks.count {
                            blankField(index: idx)
                        }
                    }
                }
            }

            if checked {
                WidgetResultBadge(allCorrect, correct: "All correct!", wrong: "\(blanks.indices.filter { isBlankCorrect($0) }.count)/\(blanks.count) correct")
            }
        }
        .onAppear {
            if answers.isEmpty { answers = Array(repeating: "", count: blanks.count) }
        }
        .onChange(of: focusedBlank) { _, newValue in
            NotificationCenter.default.post(name: .widgetInputActive, object: newValue != nil)
        }
    }

    private func isBlankCorrect(_ index: Int) -> Bool {
        guard index < answers.count, index < blanks.count else { return false }
        return answers[index].trimmingCharacters(in: .whitespaces).lowercased() == blanks[index].lowercased()
    }

    private func isOriginallyCorrect(_ index: Int) -> Bool {
        guard index < originalAnswers.count, index < blanks.count else { return false }
        return originalAnswers[index].trimmingCharacters(in: .whitespaces).lowercased() == blanks[index].lowercased()
    }

    private func blankField(index: Int) -> some View {
        let correct = checked ? isBlankCorrect(index) : nil
        let wasRevealed = revealed && correct == true && !isOriginallyCorrect(index)
        let width = max(CGFloat(blanks[index].count) * 10, 60)

        return TextField("", text: binding(for: index))
            .font(.system(size: 15, weight: checked ? .semibold : .regular))
            .multilineTextAlignment(.center)
            .foregroundColor(
                checked
                    ? (wasRevealed ? .orange : (correct == true ? .green : .red))
                    : .primary
            )
            .frame(width: width)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                checked
                    ? (wasRevealed ? Color.orange.opacity(0.1) : (correct == true ? Color.green.opacity(0.1) : Color.red.opacity(0.1)))
                    : Color.secondary.opacity(0.1)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1.5)
                    .foregroundColor(
                        checked
                            ? (wasRevealed ? .orange : (correct == true ? .green : .red))
                            : (focusedBlank == index ? .orange : .secondary.opacity(0.4))
                    ),
                alignment: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .focused($focusedBlank, equals: index)
            .disabled(checked)
            .onSubmit {
                if index + 1 < blanks.count {
                    focusedBlank = index + 1
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        originalAnswers = answers
                        checked = true
                        focusedBlank = nil
                    }
                }
            }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { if index < answers.count { answers[index] = $0 } }
        )
    }
}
