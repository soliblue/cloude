import Foundation
import Observation

@MainActor @Observable final class SessionAppStore {
    var apps: [SessionAppRuntime] = []
    var metadata: [String: SessionApp] = [:]
    var isLoading = false
    var error: String?
    var generation = UUID()
}
