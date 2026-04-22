import SwiftUI

struct SessionEmptyViewRecentListRow: View {
    let session: Session
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: session.symbol)
                    .appFont(size: ThemeTokens.Text.l)
                    .foregroundColor(.primary)
                Text(session.title)
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: ThemeTokens.Spacing.s)
                Text(relativeAge)
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var relativeAge: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.createdAt, relativeTo: Date())
    }
}
