import SwiftUI

@main
struct IOSApp: App {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, selectedTheme)
                .environment(\.fontStep, CGFloat(fontSizeStep))
        }
    }
}
