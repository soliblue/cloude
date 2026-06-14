import Foundation

@Observable
final class ChatLiveSnapshot {
    var text: String = ""
    var deltaCount: Int = 0
    var hasFirstToken: Bool = false
    var isCompacting: Bool = false
    var thinking: String = ""
    var isThinking: Bool = false
    var thinkingStartedAt: Date? = nil
    var thinkingMs: Int = 0
}
