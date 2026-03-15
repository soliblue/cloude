import SwiftUI

struct TypeAnswerWidget: View {
    let data: [String: Any]
    @State private var userInput = ""
    @State private var checked = false
    @State private var revealed = false
    @FocusState private var isFocused: Bool

    private var question: String { data["question"] as? String ?? "" }
    private var answer: String { data["answer"] as? String ?? "" }
    private var hint: String? { data["hint"] as? String }
    private var caseSensitive: Bool { data["caseSensitive"] as? Bool ?? false }

    private var isCorrect: Bool {
        caseSensitive
            ? userInput.trimmingCharacters(in: .whitespaces) == answer
            : userInput.trimmingCharacters(in: .whitespaces).lowercased() == answer.lowercased()
    }
    private var hasInput: Bool { !userInput.isEmpty }
    private var hasWrong: Bool { checked && !isCorrect }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "keyboard", title: "Type Answer", color: .cyan) {
                WidgetButton(icon: "arrow.counterclockwise", color: .cyan, enabled: hasInput || checked) {
                    userInput = ""
                    checked = false
                    revealed = false
                }
                WidgetButton(icon: "eye", color: .cyan, enabled: hasWrong && !revealed) {
                    userInput = answer
                    revealed = true
                    checked = true
                    isFocused = false
                }
                WidgetButton(icon: "checkmark.circle", color: .cyan, enabled: !checked) {
                    checked = true
                    isFocused = false
                }
            }

            Text(question)
                .font(.system(size: 15, weight: .medium))

            if let hint, !checked {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            TextField("Your answer...", text: $userInput)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)
                .disabled(checked)
                .onSubmit {
                    if !userInput.isEmpty {
                        withAnimation(.easeInOut(duration: 0.2)) { checked = true }
                        isFocused = false
                    }
                }

            if checked {
                WidgetResultBadge(isCorrect)
            }
        }
        .onChange(of: isFocused) { _, newValue in
            NotificationCenter.default.post(name: .widgetInputActive, object: newValue)
        }
    }
}
