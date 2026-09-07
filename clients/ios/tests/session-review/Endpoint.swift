import Foundation
import SwiftData

@Model final class Endpoint {
    @Attribute(.unique) var id = UUID()
    var capabilities: [String]? = ["codexReview"]
    init() {}
}
