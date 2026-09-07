import Foundation
import SwiftData

@Model final class Endpoint {
    var id = UUID()
    var connectionRevision: UUID? = nil
    var capabilities: [String]? = ["codexSteerReceipts"]
    init() {}
}
