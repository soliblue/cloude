import SwiftUI
import CloudeShared

struct TeamBannerView: View {
    let teamName: String
    let teammates: [TeammateInfo]
    @State private var showDashboard = false

    private var activeTeammates: [TeammateInfo] {
        teammates.filter { $0.status != .shutdown }
    }

    var body: some View {
        Button { showDashboard = true } label: {
            HStack(spacing: 6) {
                HStack(spacing: -4) {
                    ForEach(activeTeammates) { mate in
                        Circle()
                            .fill(teammateColor(mate.color).opacity(0.7))
                            .frame(width: 8, height: 8)
                    }
                }

                Text(teamName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showDashboard) {
            TeamDashboardSheet(teamName: teamName, teammates: teammates)
        }
    }
}

struct TeamDashboardSheet: View {
    let teamName: String
    let teammates: [TeammateInfo]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(teammates) { mate in
                        teammateRow(mate)
                    }

                    if !recentMessages.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        ForEach(recentMessages, id: \.name) { mate in
                            if let msg = mate.lastMessage {
                                messageRow(mate: mate, message: msg)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(teamName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var recentMessages: [TeammateInfo] {
        teammates
            .filter { $0.lastMessage != nil }
            .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    private func teammateRow(_ mate: TeammateInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(teammateColor(mate.color).opacity(0.7))
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(mate.name.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(mate.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(modelBadge(mate.model))
                    Text("·")
                    Text(mate.agentType)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            statusDot(mate.status)
        }
        .padding(.horizontal)
    }

    private func statusDot(_ status: TeammateStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .spawning: return ("Spawning", .orange)
            case .working: return ("Active", .green)
            case .idle: return ("Idle", .secondary)
            case .shutdown: return ("Offline", .red)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func messageRow(mate: TeammateInfo, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(teammateColor(mate.color).opacity(0.7))
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(mate.name)
                        .font(.caption.bold())
                    Spacer()
                    if let ts = mate.lastMessageAt {
                        Text(timeAgo(ts))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        let mins = Int(elapsed / 60)
        return "\(mins)m ago"
    }
}
