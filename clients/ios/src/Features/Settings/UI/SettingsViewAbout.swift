import SwiftUI

struct SettingsViewAbout: View {
    @Environment(\.theme) private var theme

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        Section {
            SettingsRow(icon: "cloud.fill", color: ThemeColor.blue) {
                Text("Remote")
                Spacer()
                Text("v\(version)")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://x.com/_xsoli")!) {
                SettingsRow(icon: "questionmark.circle", color: ThemeColor.cyan) {
                    Text("Help & Support")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(theme.palette.surface)
    }
}
