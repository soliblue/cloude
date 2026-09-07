import Foundation

struct ScheduleRunPage: Decodable {
    let runs: [ScheduleRun]
    let nextCursor: String?
}
