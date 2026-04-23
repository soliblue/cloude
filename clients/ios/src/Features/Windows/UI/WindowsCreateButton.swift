import SwiftUI

struct WindowsCreateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, ThemeTokens.Spacing.s)
                .padding(.trailing, ThemeTokens.Spacing.l)
                .frame(height: ThemeTokens.Size.xxl)
                .contentShape(WindowsCreateButtonShape())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: WindowsCreateButtonShape())
        .clipShape(WindowsCreateButtonShape())
        .offset(x: ThemeTokens.Spacing.l)
        .clipShape(Rectangle())
        .ignoresSafeArea(.keyboard)
    }
}
