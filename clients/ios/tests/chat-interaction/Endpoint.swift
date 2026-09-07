import Foundation
import SwiftData

@Model final class Endpoint {
    var id = UUID()
    var connectionRevision: UUID?
    var capabilities: [String]? = ["codexSections"]
    var cacheId: UUID { connectionRevision ?? id }
    init() {}
}
