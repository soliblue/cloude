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
    var hasCustomTitle: Bool = false
    var symbol: String
    var existsOnServer: Bool = false
    var isStreaming: Bool = false
    var hasUnread: Bool = false
    var isPinned: Bool = false
    var isArchived: Bool = false
    var needsAttention: Bool = false
    var lastSeq: Int = -1
    var hasGit: Bool = true
    var totalCostUsd: Double = 0
    var contextTokens: Int = 0
    var contextWindow: Int = 0
    var tabRaw: String = SessionTab.chat.rawValue
    var providerRaw: String? = nil
    var parentSessionId: UUID? = nil
    var pendingForkId: UUID? = nil
    var pendingForkScope: String? = nil
    var codexThreadId: String? = nil
    var codexProjectId: String? = nil
    var codexProjectName: String? = nil
    var followsRemote: Bool = false
    var remoteIsRunning: Bool = false
    var remoteTurnStatus: String? = nil
    var remoteHistoryETag: String? = nil
    var remoteHistoryOlderCursor: String? = nil
    var remoteHistoryNewerCursor: String? = nil
    var remoteHistoryPagingScope: String? = nil
    var remoteHistoryPagingInitialized: Bool = false
    var goalData: Data? = nil
    var modelRaw: String? = nil
    var effortRaw: String? = nil
    var permissionModeRaw: String? = nil

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

    var goal: ChatGoal? { goalData.flatMap { try? JSONDecoder().decode(ChatGoal.self, from: $0) } }

    var provider: ChatProvider {
        get { providerRaw.flatMap(ChatProvider.init(rawValue:)) ?? .claude }
        set { providerRaw = newValue.rawValue }
    }

    var model: ChatModel? {
        get { modelRaw.flatMap(ChatModel.init(rawValue:)) }
        set { modelRaw = newValue?.rawValue }
    }

    var effort: ChatEffort? {
        get { effortRaw.flatMap(ChatEffort.init(rawValue:)) }
        set { effortRaw = newValue?.rawValue }
    }

    var permissionMode: ChatPermissionMode {
        get {
            permissionModeRaw.flatMap(ChatPermissionMode.init(rawValue:))
                ?? (provider == .codex ? .standard : .bypassPermissions)
        }
        set { permissionModeRaw = newValue.rawValue }
    }

    var isConfigured: Bool {
        endpoint != nil && path?.isEmpty == false
    }
}
