import SwiftUI
import CloudeShared

struct QuestionView: View {
    let questions: [Question]
    let isStreaming: Bool
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void
    let onFocusChange: (Bool) -> Void

    @State private var selections: [String: Set<String>] = [:]
    @State private var contextText: [String: String] = [:]
    @State private var isSubmitting = false
    @FocusState private var focusedQuestionId: String?

    private var allQuestionsAnswered: Bool {
        questions.allSatisfy { question in
            let selected = selections[question.id] ?? []
            return !selected.isEmpty
        }
    }

    private var canSubmit: Bool {
        allQuestionsAnswered && !isStreaming && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(questions) { question in
                QuestionCard(
                    question: question,
                    selections: Binding(
                        get: { selections[question.id] ?? [] },
                        set: { selections[question.id] = $0 }
                    ),
                    context: Binding(
                        get: { contextText[question.id] ?? "" },
                        set: { contextText[question.id] = $0 }
                    ),
                    focusBinding: $focusedQuestionId
                )
            }

            HStack {
                Button(action: onDismiss) {
                    Text("Skip")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: submit) {
                    HStack(spacing: 4) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if isStreaming {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(isStreaming ? "Receiving..." : "Submit")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(canSubmit ? Color.accentColor : Color.secondary.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .disabled(!canSubmit)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.oceanSecondary)
        .cornerRadius(14)
        .onChange(of: focusedQuestionId) { _, newValue in
            onFocusChange(newValue != nil)
        }
    }

    private func submit() {
        isSubmitting = true
        let answer = formatAnswers()
        onSubmit(answer)
    }

    private func formatAnswers() -> String {
        questions.compactMap { question in
            guard let selected = selections[question.id], !selected.isEmpty else { return nil }
            let answers = question.options
                .filter { selected.contains($0.id) }
                .map { $0.label }
                .joined(separator: ", ")
            let context = contextText[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if context.isEmpty {
                return "\(question.text) \(answers)"
            } else {
                return "\(question.text) \(answers) — \(context)"
            }
        }.joined(separator: "\n")
    }
}

struct QuestionCard: View {
    let question: Question
    @Binding var selections: Set<String>
    @Binding var context: String
    var focusBinding: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.footnote)
                .fontWeight(.medium)

            VStack(spacing: 4) {
                ForEach(question.options) { option in
                    OptionRow(
                        option: option,
                        isSelected: selections.contains(option.id),
                        multiSelect: question.multiSelect
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if question.multiSelect {
                                if selections.contains(option.id) {
                                    selections.remove(option.id)
                                } else {
                                    selections.insert(option.id)
                                }
                            } else {
                                selections = [option.id]
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }

            TextField("Add details (optional)", text: $context, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(1...3)
                .padding(8)
                .background(Color.oceanTertiary)
                .cornerRadius(8)
                .focused(focusBinding, equals: question.id)
        }
    }
}

struct OptionRow: View {
    let option: QuestionOption
    let isSelected: Bool
    let multiSelect: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? (multiSelect ? "checkmark.circle.fill" : "circle.inset.filled") : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    if let desc = option.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.oceanTertiary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
