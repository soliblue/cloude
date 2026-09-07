import Foundation
import Observation

@Observable
final class ChatModelCatalog {
    static let shared = ChatModelCatalog()
    var generations: [UUID: UUID] = [:]
    var loading: Set<UUID> = []
    var errors: [UUID: String] = [:]
    var options: [UUID: [ChatModelOption]] = [:]

    func models(sessionId: UUID, provider: ChatProvider) -> [ChatModel] {
        provider == .claude
            ? ChatModel.allCases : (options[sessionId] ?? []).compactMap { ChatModel(rawValue: $0.model) }
    }

    func displayName(_ model: ChatModel?, sessionId: UUID, defaultName: String = "Auto") -> String {
        (options[sessionId] ?? []).first { $0.model == model?.rawValue }?.displayName ?? model?.displayName
            ?? defaultName
    }

    func efforts(sessionId: UUID, provider: ChatProvider, model: ChatModel?) -> [ChatEffort] {
        if provider == .codex {
            return
                ((options[sessionId] ?? []).first { $0.model == model?.rawValue }
                ?? (options[sessionId] ?? []).first { $0.isDefault })?.supportedReasoningEfforts.compactMap {
                    ChatEffort(rawValue: $0.reasoningEffort)
                } ?? [.low, .medium, .high]
        }
        return [.low, .medium, .high, .xhigh, .max]
    }
}
