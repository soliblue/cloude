import SwiftData
import SwiftUI

struct WindowsViewSwitcher: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \Window.order) private var windows: [Window]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(windows) { window in
                    if let session = window.session {
                        WindowsViewSwitcherPill(window: window, session: session, windows: windows)
                    }
                }
                addPill
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
    }

    private var addPill: some View {
        Button {
            WindowActions.addNew(into: context, after: windows)
        } label: {
            Image(systemName: "plus")
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .foregroundColor(.secondary)
                .background(theme.palette.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
