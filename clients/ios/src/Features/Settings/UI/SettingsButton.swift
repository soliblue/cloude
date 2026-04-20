import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Image(systemName: "gearshape.fill")
            .appFont(size: ThemeTokens.Icon.m)
            .foregroundColor(.secondary)
            .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
            .padding(ThemeTokens.Spacing.s)
            .glassEffect(.regular, in: Circle())
    }
}
