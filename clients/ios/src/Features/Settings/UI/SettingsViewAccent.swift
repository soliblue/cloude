import SwiftUI

struct SettingsViewAccent: View {
    @AppStorage(StorageKey.appAccent) private var selectedAccent: AppAccent = .clay

    var body: some View {
        NavigationLink {
            SettingsViewAccentPicker()
        } label: {
            SettingsRow(icon: "paintbrush.fill", color: selectedAccent.color) {
                Text("Accent")
                Spacer()
                Text(selectedAccent.rawValue)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}
