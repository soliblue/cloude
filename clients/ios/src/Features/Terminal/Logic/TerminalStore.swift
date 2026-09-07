import Foundation
import Observation

@Observable final class TerminalStore {
    var terminals: [TerminalSnapshot] = []
    var selected: TerminalSessionStore?
    var isLoading = false
    var isStarting = false
    var error: String?
    var startRequestId = UUID()
    var scope: String?
}
