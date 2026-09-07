import Foundation
import Observation

@MainActor @Observable final class SessionPluginDetailStore {
    var detail: SessionPluginDetail?
    var appsNeedingAuth: [SessionApp] = []
    var isLoading = false
    var isMutating = false
    var installed: Bool?
    var error: String?
    var generation = UUID()
    var installAttemptId = UUID()
}
