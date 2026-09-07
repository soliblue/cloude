import Foundation

struct WindowsScheduleNotification: Identifiable {
    let session: Session
    let scheduleId: UUID
    let runId: UUID
    let connectionKey: String

    var id: String { "\(connectionKey)|\(scheduleId)|\(runId)" }

    init?(route: ChatNotificationRoute, sessions: [Session]) {
        if case .schedule(let sessionId, let scheduleId, let runId) = route,
            let session = sessions.first(where: { $0.id == sessionId }),
            session.provider == .codex, let endpoint = session.endpoint,
            endpoint.capabilities?.contains("agentSchedules") == true
        {
            self.session = session
            self.scheduleId = scheduleId
            self.runId = runId
            connectionKey = session.connectionKey
        } else {
            return nil
        }
    }
}
