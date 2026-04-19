import Foundation

extension App {
    func handleWorkspaceDeepLink(host: String, url: URL) {
        switch host {
        case "file":
            dismissTransientUI()
            openFileDeepLink(url)
        case "files":
            dismissTransientUI()
            openFilesTab(path: url.queryValue(named: "path"))
        case "send":
            dismissTransientUI()
            sendDebugMessage(url.queryValue(named: "text") ?? "")
        case "search":
            dismissTransientUI()
            openConversationSearch(query: url.queryValue(named: "query"))
        case "conversation":
            dismissTransientUI()
            if url.path == "/new" {
                createNewConversation(path: url.queryValue(named: "path"))
            } else if url.path == "/duplicate" {
                duplicateActiveConversation()
            } else if url.path == "/refresh" {
                refreshActiveConversation()
            } else if url.path == "/environment",
                      let envId = url.queryValue(named: "id").flatMap(UUID.init(uuidString:)) {
                setActiveConversationEnvironment(id: envId)
            } else if url.path == "/model" {
                setActiveConversationModel(url.queryValue(named: "value"))
            } else if url.path == "/effort" {
                setActiveConversationEffort(url.queryValue(named: "value"))
            } else if let conversationId = url.queryValue(named: "id").flatMap(UUID.init(uuidString:)) {
                selectConversation(id: conversationId)
            } else {
                openConversationSearch(query: url.queryValue(named: "query"))
            }
        case "run":
            if url.path == "/stop" {
                stopActiveRun()
            }
        default:
            break
        }
    }

    func openFileDeepLink(_ url: URL) {
        let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
        if environmentStore.connection(for: envId)?.isReady == true {
            filePreviewEnvironmentId = envId
            filePathToPreview = url.path.removingPercentEncoding ?? url.path
        }
    }
}
