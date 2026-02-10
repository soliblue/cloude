import SwiftUI
import Charts
import CloudeShared

struct UsageStatsSheet: View {
    let stats: UsageStats
    @Environment(\.dismiss) private var dismiss

    private var totalToolCalls: Int {
        stats.dailyActivity.reduce(0) { $0 + $1.toolCallCount }
    }

    private var daysActive: Int {
        stats.dailyActivity.count
    }

    private var memberSinceFormatted: String? {
        guard let dateStr = stats.firstSessionDate else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: dateStr) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private var recentActivity: [DailyActivity] {
        Array(stats.dailyActivity.suffix(14))
    }

    private var sortedModels: [(name: String, tokens: ModelTokens)] {
        stats.modelUsage.sorted { $0.value.outputTokens > $1.value.outputTokens }
            .map { (name: modelDisplayName($0.key), tokens: $0.value) }
    }

    private var maxOutputTokens: Int {
        sortedModels.first?.tokens.outputTokens ?? 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCards
                    activityChart
                    modelsSection
                    peakHoursSection
                    footerSection
                }
                .padding()
            }
            .background(Color.oceanBackground)
            .navigationTitle("Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var heroCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(value: formatNumber(stats.totalMessages), label: "messages", icon: "bubble.left.and.bubble.right", color: .blue)
            StatCard(value: formatNumber(stats.totalSessions), label: "sessions", icon: "rectangle.stack", color: .purple)
            StatCard(value: formatNumber(totalToolCalls), label: "tool calls", icon: "wrench.and.screwdriver", color: .orange)
            StatCard(value: "\(daysActive)", label: "days active", icon: "calendar", color: .green)
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Activity")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Chart(recentActivity, id: \.date) { day in
                BarMark(
                    x: .value("Date", shortDate(day.date)),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(formatNumber(v))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(Color.oceanSecondary)
        .cornerRadius(16)
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Models")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ForEach(sortedModels, id: \.name) { model in
                HStack(spacing: 10) {
                    Text(model.name)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = CGFloat(model.tokens.outputTokens) / CGFloat(max(maxOutputTokens, 1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(modelColor(model.name))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                    .frame(height: 16)

                    Text(formatNumber(model.tokens.outputTokens))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40, alignment: .trailing)
                }
            }

            Text("output tokens")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color.oceanSecondary)
        .cornerRadius(16)
    }

    private var peakHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Peak Hours")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            let maxCount = stats.hourCounts.values.max() ?? 1

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = stats.hourCounts["\(hour)"] ?? 0
                    let height = CGFloat(count) / CGFloat(max(maxCount, 1))
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(peakColor(hour))
                            .frame(height: max(2, height * 50))
                    }
                }
            }
            .frame(height: 54)

            HStack {
                Text("12 AM")
                Spacer()
                Text("6 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("12 AM")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.oceanSecondary)
        .cornerRadius(16)
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            if let since = memberSinceFormatted {
                Label("Member since \(since)", systemImage: "person.crop.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let longest = stats.longestSession {
                Label("\(longest.messageCount) messages in longest session", systemImage: "trophy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let peakHour = stats.hourCounts.max(by: { $0.value < $1.value })
            if let peak = peakHour, let h = Int(peak.key) {
                Label("Peak hour: \(formatHour(h))", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else { return dateStr }
        return "\(parts[1])/\(parts[2])"
    }

    private func modelDisplayName(_ name: String) -> String {
        if name.contains("opus-4-6") { return "Opus 4.6" }
        if name.contains("opus-4-5") { return "Opus 4.5" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        return name.components(separatedBy: "-").prefix(2).joined(separator: " ").capitalized
    }

    private func modelColor(_ name: String) -> LinearGradient {
        let colors: [Color]
        switch name {
        case "Opus 4.5": colors = [.purple, .purple.opacity(0.7)]
        case "Opus 4.6": colors = [.blue, .cyan]
        case "Sonnet":   colors = [.orange, .yellow]
        case "Haiku":    colors = [.green, .mint]
        default:         colors = [.gray, .gray.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func peakColor(_ hour: Int) -> Color {
        let count = stats.hourCounts["\(hour)"] ?? 0
        let maxCount = stats.hourCounts.values.max() ?? 1
        let intensity = Double(count) / Double(max(maxCount, 1))
        return Color.blue.opacity(0.3 + intensity * 0.7)
    }

    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "12 AM" }
        if h < 12 { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.oceanSecondary)
        .cornerRadius(16)
    }
}
