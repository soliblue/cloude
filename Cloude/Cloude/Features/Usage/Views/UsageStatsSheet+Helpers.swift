import SwiftUI
import CloudeShared

extension UsageStatsSheet {
    var footerSection: some View {
        HStack(spacing: DS.Spacing.l) {
            if let since = memberSinceFormatted {
                Label(since, systemImage: "person.crop.circle")
            }
            if let longest = stats.longestSession {
                Label("\(longest.messageCount) msg record", systemImage: "trophy")
            }
            let peakHour = stats.hourCounts.max(by: { $0.value < $1.value })
            if let peak = peakHour, let h = Int(peak.key) {
                Label(formatHour(h), systemImage: "clock")
            }
        }
        .font(.system(size: DS.Text.s))
        .foregroundColor(.secondary.opacity(DS.Opacity.l))
        .padding(.top, DS.Spacing.xs)
    }

    func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    func chartDateLabel(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return dateStr }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthName = month > 0 && month <= 12 ? months[month] : "\(month)"

        let activity = recentActivity
        let idx = activity.firstIndex { $0.date == dateStr }
        let isFirst = idx == activity.startIndex
        let prevMonth: Bool = {
            guard let i = idx, i > activity.startIndex else { return false }
            let prev = activity[activity.index(before: i)].date.split(separator: "-")
            return prev.count == 3 && prev[1] != parts[1]
        }()

        if isFirst || prevMonth {
            return "\(monthName) \(day)"
        }
        return "\(day)"
    }

    func modelColor(_ name: String) -> LinearGradient {
        let colors: [Color]
        switch name {
        case "Opus 4.5": colors = [.purple, .purple.opacity(DS.Opacity.l)]
        case "Opus 4.6": colors = [.blue, .cyan]
        case "Sonnet":   colors = [.orange, .yellow]
        case "Haiku":    colors = [.green, .mint]
        default:         colors = [.gray, .gray.opacity(DS.Opacity.l)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    func peakColor(_ hour: Int) -> Color {
        let count = stats.hourCounts["\(hour)"] ?? 0
        let maxCount = stats.hourCounts.values.max() ?? 1
        let intensity = Double(count) / Double(max(maxCount, 1))
        return Color.blue.opacity(DS.Opacity.m + intensity * (1 - DS.Opacity.m))
    }

    func formatHour(_ h: Int) -> String {
        if h == 0 { return "12 AM" }
        if h < 12 { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(.system(size: DS.Icon.l, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary.opacity(DS.Opacity.l))
        }
        .frame(maxWidth: .infinity)
    }
}
