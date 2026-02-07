import Foundation

enum DateFormatters {
    private static let shared: DateFormatter = {
        let f = DateFormatter()
        return f
    }()

    static func messageTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            shared.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            shared.dateFormat = "'Yesterday' HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            shared.dateFormat = "MMM d, HH:mm"
        } else {
            shared.dateFormat = "MMM d yyyy, HH:mm"
        }
        return shared.string(from: date)
    }

    static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func mediumDate(_ date: Date) -> String {
        shared.dateStyle = .medium
        shared.timeStyle = .none
        defer {
            shared.dateStyle = .none
            shared.dateFormat = nil
        }
        return shared.string(from: date)
    }
}
