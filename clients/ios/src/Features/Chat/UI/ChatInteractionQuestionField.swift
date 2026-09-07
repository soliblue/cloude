import SwiftUI

struct ChatInteractionQuestionField: View {
    let question: ChatInteractionQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Text(question.question).font(.subheadline.weight(.medium))
            if !question.options.isEmpty {
                Picker(
                    "Choose an answer",
                    selection: Binding(
                        get: { question.options.contains(answer) ? answer : "" }, set: { answer = $0 })
                ) {
                    Text("Choose").tag("")
                    ForEach(question.options, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                if let detail = question.optionDescriptions[answer], !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            if question.valueType == "boolean" {
                Toggle("Enabled", isOn: Binding(get: { answer == "true" }, set: { answer = String($0) }))
            } else if question.isSecret && (question.options.isEmpty || question.allowsCustomAnswer) {
                SecureField("Your answer", text: $answer).textFieldStyle(.roundedBorder)
            } else if question.options.isEmpty || question.allowsCustomAnswer {
                TextField(
                    question.options.isEmpty ? "Your answer" : "Or enter a different answer", text: $answer,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
