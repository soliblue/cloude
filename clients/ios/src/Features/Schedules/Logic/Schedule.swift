import Foundation

struct Schedule: Decodable, Identifiable {
    let id: String
    let name: String
    let enabled: Bool
    let originSessionId: String
    let task: ScheduleTask
    let schedule: ScheduleTiming
    let revision: Int
    let createdAt: Double
    let updatedAt: Double
    let nextRunAt: Double?
    let activeRun: ScheduleRun?
    let lastRun: ScheduleRun?

    var nextDate: Date? { nextRunAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
}
