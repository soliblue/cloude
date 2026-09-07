import Foundation
import SwiftData

@Model final class Session {
    var id = UUID()
    var title = "Fixture"
    var symbol = "terminal"
    var hasUnread = false
    var isStreaming = true
    var needsAttention = false
    init() {}
}
