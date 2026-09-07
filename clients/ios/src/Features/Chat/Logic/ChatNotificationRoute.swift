import Foundation

enum ChatNotificationRoute: Equatable {
    case session(UUID)
    case schedule(sessionId: UUID, scheduleId: UUID, runId: UUID)

    init?(userInfo: [AnyHashable: Any]) {
        if let value = userInfo["sessionId"] as? String, let sessionId = UUID(uuidString: value) {
            if userInfo["scheduleId"] != nil || userInfo["runId"] != nil {
                if let scheduleValue = userInfo["scheduleId"] as? String,
                    let scheduleId = UUID(uuidString: scheduleValue),
                    let runValue = userInfo["runId"] as? String, let runId = UUID(uuidString: runValue)
                {
                    self = .schedule(sessionId: sessionId, scheduleId: scheduleId, runId: runId)
                } else {
                    return nil
                }
            } else {
                self = .session(sessionId)
            }
        } else {
            return nil
        }
    }
}
