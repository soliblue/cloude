import SwiftData
import SwiftUI
import UserNotifications

@main
struct IOSApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushAppDelegate
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle
    @AppStorage(StorageKey.appAccent) private var selectedAccent: AppAccent = .clay
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer
    let filePreviewPresenter = FilePreviewPresenter()

    init() {
        container = Self.makeContainer()
        EndpointActions.seedDev(context: container.mainContext)
        WindowActions.ensureOne(context: container.mainContext)
        PushNotificationCoordinator.shared.configure(context: container.mainContext)
        DaemonVersionObserver.shared.modelContext = container.mainContext
        UNUserNotificationCenter.current().delegate = ChatNotificationDelegate.shared
        AppLogger.bootstrapInfo("app launched")
    }

    var body: some Scene {
        WindowGroup {
            WindowsView()
                .environment(\.theme, selectedTheme)
                .environment(\.appAccent, selectedAccent)
                .environment(\.fontStep, CGFloat(fontSizeStep))
                .environment(\.filePreviewPresenter, filePreviewPresenter)
                .tint(selectedAccent.color)
                .onOpenURL { DeepLinkRouter.handle($0, container: container) }
                .onAppear {
                    KeyboardDismissGesture.shared.install()
                    PushNotificationCoordinator.shared.registerAll()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        PushNotificationCoordinator.shared.requestAuthorization()
                        PushNotificationCoordinator.shared.registerAll()
                    } else {
                        ChatDraftService.flushForBackground()
                    }
                }
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let models: [any PersistentModel.Type] = [
            Endpoint.self, Session.self, Window.self,
            ChatMessage.self, ChatToolCall.self, ChatGitChange.self, ChatHistoryTurnRecord.self,
            GitStatus.self, GitChange.self, GitCommit.self,
        ]
        let schema = Schema(models)
        if let container = try? ModelContainer(for: schema) { return container }
        AppLogger.bootstrapInfo("model container init failed, backing up store")
        backupDefaultStore()
        return try! ModelContainer(for: schema)
    }

    private static func backupDefaultStore() {
        let fm = FileManager.default
        if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let stamp = Int(Date().timeIntervalSince1970)
            let candidates = ["default.store", "default.store-shm", "default.store-wal"]
            for name in candidates {
                let url = dir.appendingPathComponent(name)
                try? fm.moveItem(at: url, to: dir.appendingPathComponent("\(name).bak-\(stamp)"))
            }
        }
    }
}
