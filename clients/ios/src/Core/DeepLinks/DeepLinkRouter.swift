import Foundation
import SwiftData

enum DeepLinkRouter {
    @MainActor
    static func handle(_ url: URL, container: ModelContainer) {
        if url.scheme == "cloude", let host = url.host {
            AppLogger.bootstrapInfo("deeplink url=\(url.absoluteString)")
            let path = url.path
            let context = container.mainContext
            switch host {
            case "window": handleWindow(path: path, url: url, context: context)
            case "session": handleSession(path: path, url: url, context: context)
            case "chat": handleChat(path: path, url: url, context: context)
            case "settings": NotificationCenter.default.post(name: .deeplinkOpenSettings, object: nil)
            case "screenshot": NotificationCenter.default.post(name: .deeplinkScreenshot, object: nil)
            default: AppLogger.bootstrapInfo("deeplink unhandled host=\(host)")
            }
        }
    }

    @MainActor
    private static func handleWindow(path: String, url: URL, context: ModelContext) {
        let windows = fetchWindows(context: context)
        switch path {
        case "/new":
            WindowActions.addNew(into: context, after: windows)
        case "/close":
            if let focused = windows.first(where: { $0.isFocused }) {
                WindowActions.close(focused, among: windows, context: context)
            }
        case "/activate":
            if let index = url.queryValue("index").flatMap(Int.init),
                windows.indices.contains(index)
            {
                WindowActions.activate(windows[index], among: windows)
            }
        default: break
        }
    }

    @MainActor
    private static func handleSession(path: String, url: URL, context: ModelContext) {
        if let session = focusedSession(context: context) {
            switch path {
            case "/endpoint":
                if let idString = url.queryValue("id"), let id = UUID(uuidString: idString),
                    let endpoint = fetchEndpoint(id: id, context: context)
                {
                    SessionActions.setEndpoint(endpoint, for: session)
                }
            case "/path":
                if let value = url.queryValue("value") {
                    SessionActions.setPath(value, for: session)
                }
            case "/tab":
                if let value = url.queryValue("value"), let tab = SessionTab(rawValue: value) {
                    SessionActions.setTab(tab, for: session)
                }
            default: break
            }
        }
    }

    @MainActor
    private static func handleChat(path: String, url: URL, context: ModelContext) {
        if let session = focusedSession(context: context) {
            switch path {
            case "/send":
                if let text = url.queryValue("text") {
                    ChatService.send(session: session, prompt: text, images: [], context: context)
                }
            case "/abort":
                ChatService.abort(session: session)
            default: break
            }
        }
    }

    @MainActor
    private static func fetchWindows(context: ModelContext) -> [Window] {
        let descriptor = FetchDescriptor<Window>(sortBy: [SortDescriptor(\.order)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func focusedSession(context: ModelContext) -> Session? {
        fetchWindows(context: context).first(where: { $0.isFocused })?.session
    }

    @MainActor
    private static func fetchEndpoint(id: UUID, context: ModelContext) -> Endpoint? {
        let descriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate<Endpoint> { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

extension Notification.Name {
    static let deeplinkOpenSettings = Notification.Name("cloude.deeplink.settings")
    static let deeplinkScreenshot = Notification.Name("cloude.deeplink.screenshot")
}

extension URL {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
