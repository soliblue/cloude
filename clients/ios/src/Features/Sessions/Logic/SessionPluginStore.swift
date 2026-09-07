import Foundation
import Observation

@MainActor @Observable final class SessionPluginStore {
    var entries: [SessionPluginEntry] = []
    var isLoading = false
    var error: String?
    var generation = UUID()
}
