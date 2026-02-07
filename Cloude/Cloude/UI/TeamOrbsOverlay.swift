import SwiftUI
import CloudeShared

struct TeamOrbsOverlay: View {
    let teammates: [TeammateInfo]
    @State private var selectedTeammate: TeammateInfo?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(teammates.filter { $0.status != .shutdown }) { mate in
                TeammateOrb(teammate: mate)
                    .onTapGesture { selectedTeammate = mate }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.trailing, 6)
        .padding(.vertical, 16)
        .animation(.spring(duration: 0.35), value: teammates.map(\.status))
        .sheet(item: $selectedTeammate) { mate in
            TeammateDetailSheet(teammate: mate)
        }
    }
}

struct TeammateOrb: View {
    let teammate: TeammateInfo
    @State private var isPulsing = false

    private var orbColor: Color {
        teammateColor(teammate.color)
    }

    var body: some View {
        ZStack {
            if teammate.status == .working {
                Circle()
                    .stroke(orbColor.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 34, height: 34)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
            }

            Circle()
                .fill(orbColor.opacity(0.6))
                .frame(width: 30, height: 30)

            Text(String(teammate.name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 36, height: 36)
        .opacity(teammate.status == .idle ? 0.5 : 1.0)
        .onAppear {
            if teammate.status == .working { isPulsing = true }
        }
        .onChange(of: teammate.status) { _, newStatus in
            isPulsing = (newStatus == .working)
        }
    }
}

struct TeammateDetailSheet: View {
    let teammate: TeammateInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Circle()
                    .fill(teammateColor(teammate.color).opacity(0.7))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(teammate.name.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                Text(teammate.name)
                    .font(.title3.bold())

                HStack(spacing: 12) {
                    Label(modelBadge(teammate.model), systemImage: "cpu")
                    Label(teammate.agentType, systemImage: "terminal")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                statusBadge

                if let msg = teammate.lastMessage {
                    Text(msg)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.oceanSecondary)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                if let spawnTime = timeSinceSpawn {
                    Label(spawnTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.secondary)
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

    private var timeSinceSpawn: String? {
        let elapsed = Date().timeIntervalSince(teammate.spawnedAt)
        if elapsed < 60 { return "\(Int(elapsed))s" }
        let mins = Int(elapsed / 60)
        let secs = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return "\(mins)m \(secs)s"
    }
}

func teammateColor(_ colorName: String) -> Color {
    switch colorName.lowercased() {
    case "blue": return .blue
    case "green": return .green
    case "red": return .red
    case "purple": return .purple
    case "orange": return .orange
    case "cyan": return .cyan
    case "magenta", "pink": return .pink
    case "yellow": return .yellow
    case "teal": return .teal
    case "indigo": return .indigo
    default: return .gray
    }
}

func modelBadge(_ model: String) -> String {
    let lower = model.lowercased()
    if lower.contains("opus") { return "O" }
    if lower.contains("sonnet") { return "S" }
    if lower.contains("haiku") { return "H" }
    return String(model.prefix(1)).uppercased()
}
