import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Image(systemName: "gearshape.fill")
            .appFont(size: ThemeTokens.Icon.m)
            .foregroundColor(.secondary)
            .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
            .glassEffect(.regular, in: Circle())
    }
}
