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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("Type Answer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            userInput = ""
                            checked = false
                            revealed = false
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasInput || checked ? .cyan : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput && !checked)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            userInput = answer
                            revealed = true
                            checked = true
                            isFocused = false
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong && !revealed ? .cyan : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong || revealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            checked = true
                            isFocused = false
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(checked ? .secondary.opacity(0.3) : .cyan)
                    }
                    .buttonStyle(.plain)
                    .disabled(checked)
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
                .background(Color.oceanGray6.opacity(0.5))
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
                HStack(spacing: 4) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(isCorrect ? "Correct!" : "Wrong answer")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: isFocused) { _, newValue in
            NotificationCenter.default.post(name: .widgetInputActive, object: newValue)
        }
    }
}
