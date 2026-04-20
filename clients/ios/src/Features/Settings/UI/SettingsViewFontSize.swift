import SwiftUI

struct SettingsViewFontSize: View {
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0

    var body: some View {
        SettingsRow(icon: "textformat.size", color: ThemeColor.mint) {
            Stepper("Font Size", value: $fontSizeStep, in: 0...3)
        }
    }
}
