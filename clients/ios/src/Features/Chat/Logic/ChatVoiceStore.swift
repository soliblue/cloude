import Foundation
import Observation

@MainActor @Observable final class ChatVoiceStore {
    var isVisible = false
    var isRequestingPermission = false
    var isTranscribing = false
    var generation = UUID()
    @ObservationIgnored var task: Task<Void, Never>?

    func isCurrent(_ value: UUID) -> Bool { isVisible && generation == value && !Task.isCancelled }
}
