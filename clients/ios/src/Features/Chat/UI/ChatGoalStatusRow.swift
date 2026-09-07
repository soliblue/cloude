import SwiftUI

struct ChatGoalStatusRow: View {
    let session: Session
    @State private var showingGoal = false

    var body: some View {
        if let goal = session.goal {
            Button {
                showingGoal = true
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: "target")
                    Text(goal.objective).lineLimit(1)
                    Spacer()
                    Text(goal.statusLabel).foregroundStyle(.secondary)
                }.font(.caption).padding(.horizontal, ThemeTokens.Spacing.m).padding(.vertical, ThemeTokens.Spacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Goal: \(goal.objective), \(goal.statusLabel)")
            .sheet(isPresented: $showingGoal) { ChatGoalView(session: session).id(session.connectionKey) }
        }
    }
}
