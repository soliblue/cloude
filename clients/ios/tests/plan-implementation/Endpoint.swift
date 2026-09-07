import Foundation
import SwiftData

@Model final class Endpoint {
    var id = UUID()
    var host = "remote.example"
    var port = 8765
    var supportsCodex = true
    var transportScheme = "https"
    init() {}
}
