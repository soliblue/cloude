import SwiftUI

struct FillInBlankWidget: View {
    let data: [String: Any]
    @State var answers: [String] = []
    @State var checked = false
    @State var revealed = false
    @State var originalAnswers: [String] = []
    @FocusState var focusedBlank: Int?

    var text: String { data["text"] as? String ?? "" }
    var blanks: [String] { data["blanks"] as? [String] ?? [] }
    private var hint: String? { data["hint"] as? String }
    private var hasInput: Bool { answers.contains { !$0.isEmpty } }

    var allCorrect: Bool {
        zip(answers, blanks).allSatisfy { typed, correct in
            typed.trimmingCharacters(in: .whitespaces).lowercased() == correct.lowercased()
        }
    }

    private var hasWrong: Bool { checked && !allCorrect }

    enum Token: Identifiable {
        case word(String)
        case blank(Int)

        var id: String {
            switch self {
            case .word(let s): return "w:\(s):\(UUID().uuidString.prefix(4))"
            case .blank(let i): return "b:\(i)"
            }
        }
    }

    var tokens: [Token] {
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
}
