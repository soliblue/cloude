import Foundation
import SwiftData

@Model
final class Session {
    static let defaultTitle = "Untitled"
    static let defaultSymbol = "sparkles"

    @Attribute(.unique) var id: UUID
    var endpoint: Endpoint?
    var path: String?
    var lastOpenedAt: Date
    var title: String
    var symbol: String
    var existsOnServer: Bool = false
    var tabRaw: String = SessionTab.chat.rawValue
    @Transient var skills: [Skill]? = nil
    @Transient var agents: [Agent]? = nil

    init(
        id: UUID = UUID(),
        endpoint: Endpoint? = nil,
        path: String? = nil,
        title: String = Session.defaultTitle,
        symbol: String = Session.defaultSymbol
    ) {
        self.id = id
        self.endpoint = endpoint
        self.path = path
        self.lastOpenedAt = .now
        self.title = title
        self.symbol = symbol
    }

    var tab: SessionTab {
        get { SessionTab(rawValue: tabRaw) ?? .chat }
        set { tabRaw = newValue.rawValue }
    }
}
