import SwiftUI
import CloudeShared

extension SettingsView {
    var aboutSection: some View {
        Section {
            SettingsRow(icon: "cloud.fill", color: AppColor.blue) {
                Text("Cloude")
                    .font(.system(size: DS.Text.m))
                Spacer()
                Text("v1.0")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://x.com/_xsoli")!) {
                SettingsRow(icon: "questionmark.circle", color: AppColor.cyan) {
                    Text("Help & Support")
                        .font(.system(size: DS.Text.m))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.themeSecondary)
    }
}
