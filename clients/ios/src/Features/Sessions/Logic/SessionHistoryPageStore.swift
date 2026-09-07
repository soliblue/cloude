import Foundation
import Observation

@MainActor @Observable final class SessionHistoryPageStore {
    static let shared = SessionHistoryPageStore()
    var loading: Set<UUID> = []
    var errors: [UUID: String] = [:]
}
