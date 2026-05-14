import SwiftData
import SwiftUI

@main
struct IOSApp: App {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle
    @AppStorage(StorageKey.appAccent) private var selectedAccent: AppAccent = .clay
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0
    let container: ModelContainer
    let filePreviewPresenter = FilePreviewPresenter()

    init() {
        container = Self.makeContainer()
        EndpointActions.seedDev(context: container.mainContext)
        WindowActions.ensureOne(context: container.mainContext)
        DaemonVersionObserver.shared.modelContext = container.mainContext
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
                .onAppear { KeyboardDismissGesture.shared.install() }
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let models: [any PersistentModel.Type] = [
            Endpoint.self, Session.self, Window.self,
            ChatMessage.self, ChatToolCall.self,
            GitStatus.self, GitChange.self, GitCommit.self,
        ]
        let schema = Schema(models)
        if let container = try? ModelContainer(for: schema) { return container }
        AppLogger.bootstrapInfo("model container init failed, wiping store")
        wipeDefaultStore()
        return try! ModelContainer(for: schema)
    }

    private static func wipeDefaultStore() {
        let fm = FileManager.default
        if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let candidates = ["default.store", "default.store-shm", "default.store-wal"]
            for name in candidates {
                let url = dir.appendingPathComponent(name)
                try? fm.removeItem(at: url)
            }
        }
    }
}
