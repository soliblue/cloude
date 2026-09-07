import Foundation
import SwiftData

@Model final class Endpoint {
    @Attribute(.unique) var id = UUID()
    var connectionRevision: UUID?
    var cacheId: UUID { connectionRevision ?? id }
    init() {}
}
