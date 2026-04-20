import SwiftUI
import UIKit
import CloudeShared

@MainActor
enum BackgroundStreamingTask {
    static var id: UIBackgroundTaskIdentifier = .invalid

    static func beginIfNeeded(store: ConnectionStore) {
        let anyRunning = store.connections.values.contains(where: \.hasRunningOutputs)
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
            BackgroundStreamingTask.beginIfNeeded(store: environmentStore.connectionStore)
        } else if newPhase == .active {
            BackgroundStreamingTask.end()
            if wasBackgrounded {
                handleForegroundTransition()
            } else {
                environmentStore.connectionStore.reconnectAll()
            }
            wasBackgrounded = false
        }
    }

    func handleForegroundTransition() {
        for conn in environmentStore.connectionStore.connections.values {
            if conn.hasRunningOutputs { conn.handleDisconnect() }
            if conn.hasCredentials { conn.reconnect() }
        }
    }
}
