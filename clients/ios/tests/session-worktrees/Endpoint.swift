import Foundation
import SwiftData

@Model final class Endpoint {
    @Attribute(.unique) var id = UUID()
    var supportsGitWorktrees = true
    var connectionRevision: UUID?
    init() {}
}
