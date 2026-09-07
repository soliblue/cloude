import Foundation

struct SchedulePage: Decodable {
    let schedules: [Schedule]
    let available: Bool
    let error: String?
}
