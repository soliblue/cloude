import Foundation
import ActivityKit
import CloudeShared

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activities: [String: Activity<CloudeActivityAttributes>] = [:]
    private var lastUpdateTimes: [String: Date] = [:]
    private let updateThrottleInterval: TimeInterval = 1.0

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startActivity(
        conversationId: UUID,
        conversationName: String,
        conversationSymbol: String?
    ) {
        guard isAvailable else { return }

        let convIdString = conversationId.uuidString
        if activities[convIdString] != nil { return }

        let attributes = CloudeActivityAttributes(
            conversationId: convIdString,
            conversationName: conversationName,
            conversationSymbol: conversationSymbol
        )

        let initialState = CloudeActivityAttributes.ContentState(
            agentState: .running,
            currentTool: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activities[convIdString] = activity
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func updateActivity(
        conversationId: UUID,
        agentState: AgentState,
        currentTool: String? = nil
    ) {
        let convIdString = conversationId.uuidString
        guard let activity = activities[convIdString] else { return }

        if let lastUpdate = lastUpdateTimes[convIdString],
           Date().timeIntervalSince(lastUpdate) < updateThrottleInterval {
            return
        }
        lastUpdateTimes[convIdString] = Date()

        let newState = CloudeActivityAttributes.ContentState(
            agentState: agentState,
            currentTool: currentTool
        )

        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }

    func endActivity(conversationId: UUID, finalState: AgentState = .idle) {
        let convIdString = conversationId.uuidString
        guard let activity = activities[convIdString] else { return }

        let finalContent = CloudeActivityAttributes.ContentState(
            agentState: finalState,
            currentTool: nil
        )

        Task {
            await activity.end(.init(state: finalContent, staleDate: nil), dismissalPolicy: .immediate)
            await MainActor.run {
                activities.removeValue(forKey: convIdString)
                lastUpdateTimes.removeValue(forKey: convIdString)
            }
        }
    }

    func endAllActivities() {
        for (convId, activity) in activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
            lastUpdateTimes.removeValue(forKey: convId)
        }
        activities.removeAll()
    }
}
