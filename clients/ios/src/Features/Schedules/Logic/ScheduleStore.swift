import Foundation
import Observation

@MainActor @Observable final class ScheduleStore {
    var schedules: [Schedule] = []
    var runs: [ScheduleRun] = []
    var nextCursor: String?
    var historyId: String?
    var loadedMoreRuns = false
    var available = true
    var isCached = false
    var isLoading = false
    var isMutating = false
    var uncertainSave = false
    var error: String?
    var scope: UUID?
    var generation = UUID()
    var runRequestIds: [String: UUID] = [:]
}
