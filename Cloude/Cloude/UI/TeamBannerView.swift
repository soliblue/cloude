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
            HStack(spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(teamName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                Spacer()

                HStack(spacing: -2) {
                    ForEach(activeTeammates) { mate in
                        Circle()
                            .fill(teammateColor(mate.color).opacity(0.7))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 12)
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
    @State private var expandedTeammates: Set<String> = []

    private var allMembers: [TeammateInfo] {
        let lead = TeammateInfo(
            id: "team-lead",
            name: "You (Lead)",
            agentType: "team-lead",
            model: "claude-opus-4-6",
            color: "gray",
            status: .working
        )
        return [lead] + teammates
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(allMembers) { mate in
                        VStack(spacing: 0) {
                            Button(action: {
                                if expandedTeammates.contains(mate.id) {
                                    expandedTeammates.remove(mate.id)
                                } else {
                                    expandedTeammates.insert(mate.id)
                                }
                            }) {
                                teammateRow(mate)
                            }
                            .buttonStyle(.plain)

                            if expandedTeammates.contains(mate.id) && !mate.messageHistory.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(mate.messageHistory.suffix(10).reversed()) { msg in
                                        messageRow(mate: mate, message: msg)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .background(Color(.tertiarySystemGroupedBackground))
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

    private func teammateRow(_ mate: TeammateInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(teammateColor(mate.color).opacity(0.7))
                    .frame(width: 28, height: 28)
                if mate.id == "team-lead" {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                } else {
                    Text(String(mate.name.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
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

            HStack(spacing: 8) {
                if !mate.messageHistory.isEmpty {
                    Text("\(mate.messageHistory.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                statusDot(mate.status)
                Image(systemName: expandedTeammates.contains(mate.id) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))
            }
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

    private func messageRow(mate: TeammateInfo, message: TeammateMessage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(teammateColor(mate.color).opacity(0.7))
                    .frame(width: 4, height: 4)
                Text(timeAgo(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
            }
            Text(message.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .padding(.leading, 8)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        let mins = Int(elapsed / 60)
        return "\(mins)m ago"
    }
}
