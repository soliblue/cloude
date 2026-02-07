import SwiftUI
import CloudeShared

struct TeammateDetailSheet: View {
    let teammate: TeammateInfo
    @Environment(\.dismiss) private var dismiss

    private var orbColor: Color { teammateColor(teammate.color) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, 20)

                    if teammate.messageHistory.isEmpty {
                        ContentUnavailableView(
                            "No Messages",
                            systemImage: "bubble.left",
                            description: Text("Messages from \(teammate.name) will appear here")
                        )
                        .padding(.top, 24)
                    } else {
                        messagesSection
                    }
                }
                .padding(.top, 20)
            }
            .navigationTitle(teammate.name)
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

    private var headerSection: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(orbColor.opacity(0.7))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String(teammate.name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

            HStack(spacing: 8) {
                Label(modelBadge(teammate.model), systemImage: "cpu")
                Text("·")
                Label(teammate.agentType, systemImage: "terminal")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
    }

    private var messagesSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(teammate.messageHistory) { msg in
                messageRow(msg)
            }
        }
    }

    private func messageRow(_ msg: TeammateMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.text)
                .font(.callout)
                .foregroundColor(.primary)

            Text(formatTime(msg.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(orbColor.opacity(0.4))
                .frame(width: 2)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var statusColor: Color {
        switch teammate.status {
        case .spawning: return .orange
        case .working: return .green
        case .idle: return .secondary
        case .shutdown: return .red
        }
    }

    private var statusText: String {
        switch teammate.status {
        case .spawning: return "Spawning"
        case .working: return "Working"
        case .idle: return "Idle"
        case .shutdown: return "Shut down"
        }
    }
}
