import Foundation
import SwiftData

@Model final class ChatToolCall {
    enum State: String { case pending, failed }
    var sessionId: UUID
    var stateRaw = "pending"
    var state: State {
        get { State(rawValue: stateRaw)! }
        set { stateRaw = newValue.rawValue }
    }
    init(sessionId: UUID) { self.sessionId = sessionId }
    static func prettyJSON(_ value: Any) -> String { "{}" }
}
