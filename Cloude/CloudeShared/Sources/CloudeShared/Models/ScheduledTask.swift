import Foundation

public enum TaskSchedule: Codable, Equatable {
    case oneTime(Date)
    case recurring(String)

    enum CodingKeys: String, CodingKey {
        case type, date, cron
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "one_time" {
            let date = try container.decode(Date.self, forKey: .date)
            self = .oneTime(date)
        } else {
            let cron = try container.decode(String.self, forKey: .cron)
            self = .recurring(cron)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .oneTime(let date):
            try container.encode("one_time", forKey: .type)
            try container.encode(date, forKey: .date)
        case .recurring(let cron):
            try container.encode("recurring", forKey: .type)
            try container.encode(cron, forKey: .cron)
        }
    }

    public var displayString: String {
        switch self {
        case .oneTime(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        case .recurring(let cron):
            return CronFormatter.describe(cron)
        }
    }
}

public struct ScheduledTask: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var prompt: String
    public var schedule: TaskSchedule
    public var conversationId: String
    public var isActive: Bool
    public var lastRun: Date?
    public var nextRun: Date?
    public var createdAt: Date
    public var workingDirectory: String?

    public init(id: String, name: String, prompt: String, schedule: TaskSchedule, conversationId: String, isActive: Bool, lastRun: Date? = nil, nextRun: Date? = nil, createdAt: Date, workingDirectory: String? = nil) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.schedule = schedule
        self.conversationId = conversationId
        self.isActive = isActive
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.createdAt = createdAt
        self.workingDirectory = workingDirectory
    }
}

public enum CronFormatter {
    public static func describe(_ cron: String) -> String {
        let parts = cron.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return cron }

        let minute = parts[0]
        let hour = parts[1]
        let dayOfMonth = parts[2]
        let month = parts[3]
        let dayOfWeek = parts[4]

        let timeStr: String
        if let h = Int(hour), let m = Int(minute) {
            let period = h >= 12 ? "PM" : "AM"
            let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            timeStr = String(format: "%d:%02d %@", displayHour, m, period)
        } else {
            timeStr = "\(hour):\(minute)"
        }

        if dayOfMonth == "*" && month == "*" {
            if dayOfWeek == "*" {
                return "Daily at \(timeStr)"
            }
            let days = dayOfWeek.split(separator: ",").compactMap { dayName(Int(String($0))) }
            if days.count == 5 && !dayOfWeek.contains("0") && !dayOfWeek.contains("6") {
                return "Weekdays at \(timeStr)"
            }
            return "\(days.joined(separator: ", ")) at \(timeStr)"
        }

        return cron
    }

    private static func dayName(_ day: Int?) -> String? {
        switch day {
        case 0: return "Sun"
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        default: return nil
        }
    }
}
