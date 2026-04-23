import SwiftUI

struct SettingsViewAbout: View {
    var body: some View {
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
}
