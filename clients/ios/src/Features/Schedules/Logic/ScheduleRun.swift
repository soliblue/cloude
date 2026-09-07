import Foundation

struct ScheduleRun: Decodable, Identifiable {
    let runId: String
    let sessionId: String
    let scheduleId: String
    let originSessionId: String
    let name: String
    let provider: String
    let path: String
    let threadId: String?
    let scheduledFor: Double
    let createdAt: Double
    let startedAt: Double?
    let finishedAt: Double?
    let status: String
    let error: String?

    var id: String { runId }
    var date: Date { Date(timeIntervalSince1970: scheduledFor / 1000) }
    var isActive: Bool { ["starting", "running", "waiting"].contains(status) }
}
