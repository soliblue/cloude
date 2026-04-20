import SwiftUI

struct SettingsViewTheme: View {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle

    var body: some View {
        NavigationLink {
            SettingsViewThemePicker()
        } label: {
            SettingsRow(icon: "paintpalette.fill", color: ThemeColor.purple) {
                Text("Theme")
                Spacer()
                Text(selectedTheme.rawValue)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}
