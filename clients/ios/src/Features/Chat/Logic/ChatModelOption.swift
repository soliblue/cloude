import Foundation

struct ChatModelOption: Decodable, Identifiable {
    let id: String
    let model: String
    let displayName: String
    let isDefault: Bool
    let supportedReasoningEfforts: [ChatReasoningOption]
    let defaultReasoningEffort: String
}
