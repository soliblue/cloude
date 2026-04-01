import Foundation
import Combine
import CloudeShared

final class PlansStore: ObservableObject {
    @Published var isPresented = false
    @Published var stages: [String: [PlanItem]] = [:]
    @Published var initialStage: String?
    @Published var isLoading = false
    @Published var fromCache = false

    func open(connection: ConnectionManager, windowManager: WindowManager, conversationStore: ConversationStore, environmentStore: EnvironmentStore) {
        AppLogger.beginInterval("plans.open")
        let activeEnvConn = connection.connection(for: environmentStore.activeEnvironmentId)
        let workingDirectory = windowManager.activeWindow?.conversation(in: conversationStore)?.workingDirectory ?? activeEnvConn?.defaultWorkingDirectory ?? connection.defaultWorkingDirectory
        if let cached = PlansCache.load() {
            stages = cached.stages
            fromCache = true
            isLoading = connection.isAuthenticated && workingDirectory != nil
        } else {
            stages = [:]
            fromCache = false
            isLoading = workingDirectory != nil
        }
        if let workingDirectory {
            connection.getPlans(workingDirectory: workingDirectory, environmentId: environmentStore.activeEnvironmentId)
        }
        isPresented = true
    }

    func handle(stages: [String: [PlanItem]]) {
        AppLogger.endInterval("plans.open", details: "stages=\(stages.count)")
        self.stages = stages
        fromCache = false
        isLoading = false
        PlansCache.save(stages)
    }

    func handleDeleted(stage: String, filename: String) {
        stages[stage]?.removeAll { $0.filename == filename }
    }

    func handleDefaultWorkingDirectory(_ path: String, environmentId: UUID?, connection: ConnectionManager) {
        if isPresented && stages.isEmpty && !isLoading {
            isLoading = true
            connection.getPlans(workingDirectory: path, environmentId: environmentId)
        }
    }
}
