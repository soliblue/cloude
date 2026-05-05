import Foundation

enum SessionToastKind: Equatable {
    case session(UUID)
    case daemonUpdate(endpointId: UUID)
}

struct SessionToast: Identifiable, Equatable {
    let id = UUID()
    let kind: SessionToastKind
    let title: String
    let symbol: String
    let snippet: String

    init(sessionId: UUID, title: String, symbol: String, snippet: String) {
        self.kind = .session(sessionId)
        self.title = title
        self.symbol = symbol
        self.snippet = snippet
    }

    init(kind: SessionToastKind, title: String, symbol: String, snippet: String) {
        self.kind = kind
        self.title = title
        self.symbol = symbol
        self.snippet = snippet
    }

    var sessionId: UUID? {
        if case .session(let id) = kind { return id }
        return nil
    }
}
