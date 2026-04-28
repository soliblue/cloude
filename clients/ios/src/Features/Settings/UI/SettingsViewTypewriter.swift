import SwiftUI

struct SettingsViewTypewriter: View {
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps

    var body: some View {
        NavigationLink {
            SettingsViewTypewriterTuner()
        } label: {
            SettingsRow(icon: "text.cursor", color: ThemeColor.blue) {
                Text("Typewriter")
                Spacer()
                Text("\(Int(cps)) cps")
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}
