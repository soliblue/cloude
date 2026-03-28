import Foundation
import CloudeShared

struct GitDiffRequest: Identifiable {
    let id = UUID()
    let repoPath: String
    let file: GitFileStatus
    let environmentId: UUID?
}

extension CloudeApp {
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "cloude" else { return }
        AppLogger.bootstrapInfo("handle deep link url=\(url.absoluteString)")

        switch url.host {
        case "file":
            dismissTransientUI()
            openFileDeepLink(url)
        case "files":
            dismissTransientUI()
            openFilesTab(path: url.queryValue(named: "path"))
        case "git":
            dismissTransientUI()
            if url.path == "/diff",
               let file = url.queryValue(named: "file") {
                openGitDiff(
                    repoPath: url.queryValue(named: "repo") ?? url.queryValue(named: "path"),
                    filePath: file,
                    staged: url.boolQueryValue(named: "staged") ?? false
                )
            } else {
                openGitTab(path: url.queryValue(named: "path"))
            }
        case "send":
            dismissTransientUI()
            sendDebugMessage(url.queryValue(named: "text") ?? "")
        case "screenshot":
            captureScreenshot()
        case "usage":
            dismissTransientUI()
            openUsageStats()
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
        case "window":
            dismissTransientUI()
            if url.path == "/new" {
                createWindow(type: url.queryValue(named: "type").flatMap(WindowType.init(rawValue:)))
            } else if url.path == "/close" {
                closeActiveWindow()
            } else if url.path == "/edit" {
                openEditActiveWindow()
            } else if let indexValue = url.queryValue(named: "index"),
                      let index = Int(indexValue) {
                selectWindow(index: index)
            }
        case "run":
            if url.path == "/stop" {
                stopActiveRun()
            }
        case "tab":
            dismissTransientUI()
            if let type = url.queryValue(named: "type").flatMap(WindowType.init(rawValue:)) {
                setActiveWindowType(type)
            }
        case "environment":
            if let envId = url.queryValue(named: "id").flatMap(UUID.init(uuidString:)) {
                switch url.path {
                case "/select":
                    selectEnvironment(id: envId)
                case "/connect":
                    connectEnvironment(id: envId)
                case "/disconnect":
                    disconnectEnvironment(id: envId)
                default:
                    break
                }
            }
        case "settings":
            dismissTransientUI()
            showSettings = true
        case "memory", "memories":
            dismissTransientUI()
            openMemories()
        case "plans":
            dismissTransientUI()
            initialPlanStage = url.queryValue(named: "stage")
            openPlans()
        case "whiteboard":
            dismissTransientUI()
            if url.path == "/snapshot" {
                handleWhiteboardAction(action: "snapshot", json: [:], conversationId: nil)
            } else if url.path == "/export" {
                handleWhiteboardAction(action: "export", json: [:], conversationId: nil)
            } else {
                whiteboardStore.load(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
                showWhiteboard = true
            }
        default:
            break
        }
    }

    private func openFileDeepLink(_ url: URL) {
        let envId = windowManager.activeWindow?.conversation(in: conversationStore)?.environmentId ?? environmentStore.activeEnvironmentId
        guard connection.connection(for: envId)?.isAuthenticated == true else { return }
        filePreviewEnvironmentId = envId
        filePathToPreview = url.path.removingPercentEncoding ?? url.path
    }
}

private extension URL {
    func queryValue(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    func boolQueryValue(named name: String) -> Bool? {
        guard let value = queryValue(named: name)?.lowercased() else { return nil }
        switch value {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }
}
