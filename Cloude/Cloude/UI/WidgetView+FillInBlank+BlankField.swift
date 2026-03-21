import SwiftUI

extension FillInBlankWidget {
    func isBlankCorrect(_ index: Int) -> Bool {
        guard index < answers.count, index < blanks.count else { return false }
        return answers[index].trimmingCharacters(in: .whitespaces).lowercased() == blanks[index].lowercased()
    }

    func isOriginallyCorrect(_ index: Int) -> Bool {
        guard index < originalAnswers.count, index < blanks.count else { return false }
        return originalAnswers[index].trimmingCharacters(in: .whitespaces).lowercased() == blanks[index].lowercased()
    }

    func blankField(index: Int) -> some View {
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
                    withAnimation(.quickTransition) {
                        originalAnswers = answers
                        checked = true
                        focusedBlank = nil
                    }
                }
            }
    }

    func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { if index < answers.count { answers[index] = $0 } }
        )
    }
}
