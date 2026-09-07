import SwiftUI

struct ChatInteractionCard: View {
    let session: Session
    let request: ChatInteraction
    @State private var answers: [String: String] = [:]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label(request.title, systemImage: "hand.raised.fill")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    Text(request.detail).font(.subheadline).textSelection(.enabled)
                    if let raw = request.params["url"] as? String, let url = URL(string: raw), url.scheme == "https" {
                        Link("Open requested form", destination: url)
                    }
                    if request.questions.isEmpty {
                        DisclosureGroup("Action details") {
                            Text(request.paramsJSON).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    ForEach(request.questions) { question in
                        ChatInteractionQuestionField(
                            question: question,
                            answer: Binding(
                                get: { answers[question.id] ?? question.defaultValue },
                                set: { answers[question.id] = $0 }))
                    }
                }
            }
            .frame(maxHeight: 220)
            if let error = ChatInteractionStore.shared.errors[request.id] {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                if request.questions.isEmpty {
                    Button("Decline", role: .destructive) {
                        Task {
                            await ChatInteractionService.respond(
                                session: session, request: request, result: request.approvalResult("decline"))
                        }
                    }
                    Spacer()
                    Button("Approve") {
                        Task {
                            await ChatInteractionService.respond(
                                session: session, request: request, result: request.approvalResult("accept"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .contextMenu {
                        if request.method != "mcpServer/elicitation/request" {
                            Button("Approve for this session") {
                                Task {
                                    await ChatInteractionService.respond(
                                        session: session, request: request,
                                        result: request.approvalResult("acceptForSession"))
                                }
                            }
                        }
                    }
                } else {
                    if request.method == "mcpServer/elicitation/request" {
                        Button("Decline", role: .destructive) {
                            Task {
                                await ChatInteractionService.respond(
                                    session: session, request: request, result: request.approvalResult("decline"))
                            }
                        }
                    }
                    Button("Send answers") {
                        Task {
                            await ChatInteractionService.respond(
                                session: session, request: request,
                                result: request.answersResult(answers))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        request.questions.contains {
                            $0.value(answers[$0.id] ?? $0.defaultValue) == nil
                        })
                }
                if ChatInteractionStore.shared.submitting.contains(request.id) { ProgressView() }
            }
            .disabled(ChatInteractionStore.shared.submitting.contains(request.id))
        }
        .padding(ThemeTokens.Spacing.m)
        .background(theme.palette.background)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m).stroke(.orange.opacity(0.6)))
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }
}
