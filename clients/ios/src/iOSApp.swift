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
        container = try! ModelContainer(
            for: Endpoint.self,
            Session.self,
            Window.self,
            ChatMessage.self,
            ChatToolCall.self,
            GitStatus.self,
            GitChange.self,
            GitCommit.self
        )
        EndpointActions.seedDev(context: container.mainContext)
        WindowActions.ensureOne(context: container.mainContext)
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
}
