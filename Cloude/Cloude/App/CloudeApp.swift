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
    @State var initialPlanStage: String? = nil
    @State var isLoadingPlans = false
    @State var plansFromCache = false
    @State var wasBackgrounded = false
    @State var lastActiveSessionId: String? = nil
    @State var filePathToPreview: String? = nil
    @State var filePreviewEnvironmentId: UUID? = nil
    @State var fileBrowserRootOverrides: [UUID: String] = [:]
    @State var gitRepoRootOverrides: [UUID: String] = [:]
    @State var gitDiffRequest: GitDiffRequest?
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.majorelle.rawValue
    var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @AppStorage("debugOverlayEnabled") var debugOverlayEnabled = false
    @AppStorage("fontSizeStep") var fontSizeStep: Int = 0
    let debugMetrics = DebugMetrics.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            mainContent
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
