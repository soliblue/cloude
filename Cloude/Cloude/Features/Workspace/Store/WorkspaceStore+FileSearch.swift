import Foundation

extension WorkspaceStore {
    func searchFiles(
        _ query: String,
        environmentStore: EnvironmentStore,
        conversationStore: ConversationStore,
        windowManager: WindowManager
    ) {
        let runtime = activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
        if let workingDir = runtime.workingDirectory, !workingDir.isEmpty {
            runtime.connection?.files.search(query: query, workingDirectory: workingDir)
        } else {
            runtime.connection?.files.clearSearch()
        }
    }
}
