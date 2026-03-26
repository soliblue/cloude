import SwiftUI
import Combine
import CloudeShared
import UIKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@main
struct CloudeApp: App {
    @StateObject var connection = ConnectionManager()
    @StateObject var conversationStore = ConversationStore()
    @StateObject var windowManager = WindowManager()
    @StateObject var environmentStore = EnvironmentStore()
    @StateObject var whiteboardStore = WhiteboardStore()
    @State var showSettings = false
    @State var showMemories = false
    @State var memorySections: [MemorySection] = []
    @State var isLoadingMemories = false
    @State var memoriesFromCache = false
    @State var showPlans = false
    @State var showWhiteboard = false
    @State var planStages: [String: [PlanItem]] = [:]
    @State var isLoadingPlans = false
    @State var plansFromCache = false
    @State var wasBackgrounded = false
    @State var lastActiveSessionId: String? = nil
    @State var isUnlocked = false
    @State var filePathToPreview: String? = nil
    @State var filePreviewEnvironmentId: UUID? = nil
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.majorelle.rawValue
    var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @AppStorage("requireBiometricAuth") var requireBiometricAuth = false
    @AppStorage("debugOverlayEnabled") var debugOverlayEnabled = false
    let debugMetrics = DebugMetrics.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if requireBiometricAuth && !isUnlocked {
                    LockScreenView(onUnlock: { isUnlocked = true })
                } else {
                    mainContent
                }
            }
            .overlay { FullscreenColorOverlay() }
            .overlay {
                if debugOverlayEnabled {
                    DebugOverlayView()
                }
            }
            .environmentObject(connection)
            .environment(\.appTheme, appTheme)
            .preferredColorScheme(appTheme.colorScheme)
        }
    }
}
