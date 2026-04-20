import Foundation
import SwiftData

@Model
final class Window {
    var session: Session?
    var order: Int
    var isFocused: Bool

    init(session: Session? = nil, order: Int = 0, isFocused: Bool = false) {
        self.session = session
        self.order = order
        self.isFocused = isFocused
    }
}
