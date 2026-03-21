import SwiftUI
import CloudeShared

extension TeamDashboardSheet {
    func teammateRow(_ mate: TeammateInfo) -> some View {
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

    func statusDot(_ status: TeammateStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .spawning: return ("Spawning", .orange)
            case .working: return ("Active", .pastelGreen)
            case .idle: return ("Idle", .secondary)
            case .shutdown: return ("Offline", .pastelRed)
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

    func messageRow(mate: TeammateInfo, message: TeammateMessage) -> some View {
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

    func timeAgo(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        let mins = Int(elapsed / 60)
        return "\(mins)m ago"
    }
}
