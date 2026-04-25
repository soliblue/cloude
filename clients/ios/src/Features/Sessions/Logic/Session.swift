import Foundation
import SwiftData

@Model
final class Session {
    static let defaultTitle = "Untitled"
    static let defaultSymbol = "sparkles"

    @Attribute(.unique) var id: UUID
    var endpoint: Endpoint?
    var path: String?
    var createdAt: Date = Date.distantPast
    var lastOpenedAt: Date
    var title: String
    var symbol: String
    var existsOnServer: Bool = false
    var isStreaming: Bool = false
    var lastSeq: Int = -1
    var hasGit: Bool = true
    var totalCostUsd: Double = 0
    var tabRaw: String = SessionTab.chat.rawValue
    var modelRaw: String? = nil
    var effortRaw: String? = nil
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
        self.createdAt = .now
        self.lastOpenedAt = .now
        self.title = title
        self.symbol = symbol
    }

    var tab: SessionTab {
        get { SessionTab(rawValue: tabRaw) ?? .chat }
        set { tabRaw = newValue.rawValue }
    }

    var model: ChatModel? {
        get { modelRaw.flatMap(ChatModel.init(rawValue:)) }
        set { modelRaw = newValue?.rawValue }
    }

    var effort: ChatEffort? {
        get { effortRaw.flatMap(ChatEffort.init(rawValue:)) }
        set { effortRaw = newValue?.rawValue }
    }

    var isConfigured: Bool {
        endpoint != nil && path?.isEmpty == false
    }
}
