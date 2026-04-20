import SwiftData
import SwiftUI

@main
struct IOSApp: App {
    @AppStorage(StorageKey.appTheme) private var selectedTheme: Theme = .majorelle
    @AppStorage(StorageKey.fontSizeStep) private var fontSizeStep = 0
    let container: ModelContainer

    init() {
        container = try! ModelContainer(for: Endpoint.self, Session.self, Window.self)
        EndpointActions.seedDev(context: container.mainContext)
        WindowActions.ensureOne(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            WindowsView()
                .environment(\.theme, selectedTheme)
                .environment(\.fontStep, CGFloat(fontSizeStep))
        }
        .modelContainer(container)
    }
}
