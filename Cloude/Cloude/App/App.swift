import SwiftUI
import CloudeShared

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@main
struct App: SwiftUI.App {
    @StateObject var conversationStore = ConversationStore()
    @StateObject var windowManager = WindowManager()
    @StateObject var environmentStore = EnvironmentStore()
    @StateObject var settingsStore = SettingsStore()
    @State var wasBackgrounded = false
    @State var filePathToPreview: String? = nil
    @State var filePreviewEnvironmentId: UUID? = nil
    @State var gitDiffRequest: GitDiffRequest?
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.majorelle.rawValue
    var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @AppStorage("debugOverlayEnabled") var debugOverlayEnabled = false
    @AppStorage("fontSizeStep") var fontSizeStep: Int = 0
    let debugMetrics = DebugMetrics.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            shell
            .overlay {
                if debugOverlayEnabled {
                    AppDebugOverlay()
                }
            }
            .environmentObject(environmentStore)
            .environment(\.appTheme, appTheme)
            .preferredColorScheme(appTheme.colorScheme)
        }
    }
}
