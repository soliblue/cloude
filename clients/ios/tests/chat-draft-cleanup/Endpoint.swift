import Foundation
import SwiftData

@Model final class Endpoint {
    var id = UUID()
    var supportsCodex = false
    init() {}
}
