import Foundation

struct ScheduleTiming: Codable {
    var kind: String
    var time: String?
    var timeZone: String?
    var daysOfWeek: [Int]?
    var minutes: Int?

    var summary: String {
        if kind == "interval" { return "Every \(minutes ?? 60) minutes" }
        let days = Set(daysOfWeek ?? [])
        let frequency = days == Set(1...7) ? "Daily" : days == Set(1...5) ? "Weekdays" : "Selected days"
        return "\(frequency) at \(time ?? "09:00") · \(timeZone ?? "UTC")"
    }
}
