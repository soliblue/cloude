import SwiftUI

struct SessionEmptyViewHero: View {
    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.s) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)
                .padding(ThemeTokens.Spacing.s)
            Text("Afto").font(.title2.weight(.semibold))
            Text("Your agents. Any machine.").font(.headline)
            Text("Choose a machine and project, then pick up where you left off.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, ThemeTokens.Spacing.m)
    }
}
