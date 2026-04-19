import SwiftUI
import UIKit
import CloudeShared

@MainActor
enum BackgroundStreamingTask {
    static var id: UIBackgroundTaskIdentifier = .invalid

    static func beginIfNeeded(store: EnvironmentStore) {
        let anyRunning = store.connections.values.contains { $0.conversationOutputs.values.contains { $0.phase != .idle } }
        if anyRunning, id == .invalid {
            id = UIApplication.shared.beginBackgroundTask(withName: "StreamingResponse") {
                Task { @MainActor in BackgroundStreamingTask.end() }
            }
        }
    }

    static func end() {
        if id != .invalid {
            let taskId = id
            id = .invalid
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
}

extension App {
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background {
            wasBackgrounded = true
            BackgroundStreamingTask.beginIfNeeded(store: environmentStore)
        } else if newPhase == .active {
            BackgroundStreamingTask.end()
            if wasBackgrounded {
                handleForegroundTransition()
            } else {
                environmentStore.reconnectAll()
            }
            wasBackgrounded = false
        }
    }

    func handleForegroundTransition() {
        for conn in environmentStore.connections.values {
            if !conn.runningOutputs.isEmpty { conn.handleDisconnect() }
            if conn.hasCredentials { conn.reconnect() }
        }
    }
}
