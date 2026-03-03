import SwiftUI

extension Notification.Name {
    static let widgetInputActive = Notification.Name("widgetInputActive")
}

struct FillInBlankWidget: View {
    let data: [String: Any]
    @State private var answers: [String] = []
    @State private var checked = false
    @State private var revealed = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                if let hint {
                    Text(hint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            answers = Array(repeating: "", count: blanks.count)
                            checked = false
                            revealed = false
                            focusedBlank = nil
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasInput || checked ? .orange : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput && !checked)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            for i in blanks.indices {
                                if !isBlankCorrect(i) { answers[i] = blanks[i] }
                            }
                            revealed = true
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong && !revealed ? .orange : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong || revealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            originalAnswers = answers
                            checked = true
                            focusedBlank = nil
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(checked ? .secondary.opacity(0.3) : .orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(checked)
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
                HStack(spacing: 4) {
                    Image(systemName: allCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(allCorrect ? "All correct!" : "\(blanks.indices.filter { isBlankCorrect($0) }.count)/\(blanks.count) correct")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    @State private var originalAnswers: [String] = []

    private func isOriginallyCorrect(_ index: Int) -> Bool {
        guard index < originalAnswers.count, index < blanks.count else { return false }
        return originalAnswers[index].trimmingCharacters(in: .whitespaces).lowercased() == blanks[index].lowercased()
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { if index < answers.count { answers[index] = $0 } }
        )
    }
}
