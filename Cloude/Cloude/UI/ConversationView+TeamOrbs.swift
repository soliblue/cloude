import SwiftUI
import CloudeShared

struct TeamOrbsOverlay: View {
    let teammates: [TeammateInfo]
    var onClearUnread: ((String) -> Void)?
    @State private var selectedTeammate: TeammateInfo?

    private var activeTeammates: [TeammateInfo] {
        teammates.filter { $0.status != .shutdown }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            ForEach(activeTeammates) { mate in
                TeammateOrbRow(
                    teammate: mate,
                    onTap: {
                        onClearUnread?(mate.id)
                        selectedTeammate = mate
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.trailing, 6)
        .padding(.vertical, 16)
        .animation(.spring(duration: 0.35), value: activeTeammates.map(\.status))
        .sheet(item: $selectedTeammate) { mate in
            TeammateDetailSheet(teammate: mate)
        }
    }
}

func teammateColor(_ colorName: String) -> Color {
    .fromName(colorName, default: .gray)
}

func modelBadge(_ model: String) -> String {
    ModelIdentity(model).badge
}
