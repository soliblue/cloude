import Foundation
import SwiftData

@Model final class Session {
    var id = UUID()
    var endpoint: Endpoint?
    init(endpoint: Endpoint) { self.endpoint = endpoint }
}
