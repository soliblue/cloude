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
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(teamName)
                    .font(.footnote.weight(.medium))
                    .fontDesign(.rounded)
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
    @State var expandedTeammates: Set<String> = []

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
                                .background(Color.themeTertiary)
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.themeBackground)
    }
}
