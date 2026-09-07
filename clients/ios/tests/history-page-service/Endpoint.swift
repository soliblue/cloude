import Foundation
import SwiftData

@Model final class Endpoint {
    @Attribute(.unique) var id = UUID()
    var connectionRevision: UUID?
    var capabilities: [String]? = ["codexHistoryPages"]
    var host = "fixture.invalid"
    var name = "Original host"
    var port = 8765
    var transportScheme = "http"
    var cacheId: UUID { connectionRevision ?? id }
    init() {}
}
