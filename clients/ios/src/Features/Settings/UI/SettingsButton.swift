import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .appFont(size: ThemeTokens.Icon.m)
            .foregroundColor(.secondary)
            .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
    }
}
