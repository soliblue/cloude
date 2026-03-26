import SwiftUI
import Charts
import CloudeShared

struct UsageStatsSheet: View {
    let stats: UsageStats
    @Environment(\.dismiss) private var dismiss
    @State var selectedTimeRange: TimeRange?
    @State var chartPage = 0

    let timeRanges = [
        TimeRange(label: "7d", days: 7),
        TimeRange(label: "14d", days: 14),
        TimeRange(label: "30d", days: 30),
        TimeRange(label: "All", days: nil)
    ]

    var totalToolCalls: Int {
        stats.dailyActivity.reduce(0) { $0 + $1.toolCallCount }
    }

    var daysActive: Int { stats.dailyActivity.count }

    var memberSinceFormatted: String? {
        guard let dateStr = stats.firstSessionDate else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: dateStr) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    var recentActivity: [DailyActivity] {
        if let days = selectedTimeRange?.days {
            return Array(stats.dailyActivity.suffix(days))
        }
        return stats.dailyActivity
    }

    var sortedModels: [(name: String, tokens: ModelTokens)] {
        stats.modelUsage.sorted { $0.value.outputTokens > $1.value.outputTokens }
            .map { (name: modelDisplayName($0.key), tokens: $0.value) }
    }

    func modelDisplayName(_ name: String) -> String {
        ModelIdentity(name).displayName
    }

    var maxOutputTokens: Int { sortedModels.first?.tokens.outputTokens ?? 1 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.l) {
                    heroRow
                    activityChart
                    modelsSection
                    peakHoursSection
                    footerSection
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.themeBackground)
    }

    private var heroRow: some View {
        HStack(spacing: 0) {
            StatPill(value: formatNumber(stats.totalMessages), label: "msgs", color: .blue)
            Divider().frame(height: 28).padding(.horizontal, DS.Spacing.xs)
            StatPill(value: formatNumber(stats.totalSessions), label: "sessions", color: .purple)
            Divider().frame(height: 28).padding(.horizontal, DS.Spacing.xs)
            StatPill(value: formatNumber(totalToolCalls), label: "tools", color: .orange)
            Divider().frame(height: 28).padding(.horizontal, DS.Spacing.xs)
            StatPill(value: "\(daysActive)", label: "days", color: .green)
        }
        .padding(.vertical, DS.Spacing.m)
        .padding(.horizontal, DS.Spacing.l)
        .background(.white.opacity(0.08))
        .cornerRadius(DS.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

}
