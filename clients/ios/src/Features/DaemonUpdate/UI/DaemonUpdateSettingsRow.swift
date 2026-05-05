import SwiftUI

struct DaemonUpdateSettingsRow: View {
    var body: some View {
        NavigationLink {
            DaemonUpdateView()
        } label: {
            SettingsRow(icon: "arrow.down.circle.fill", color: ThemeColor.green) {
                Text("Install Daemon")
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }
}
