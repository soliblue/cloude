import Foundation

@main struct ScheduleNotificationTests {
    @MainActor static func main() {
        let origin = Session()
        let unrelated = Session()
        let scheduleId = UUID()
        let runId = UUID()
        let payload: [AnyHashable: Any] = [
            "sessionId": origin.id.uuidString, "scheduleId": scheduleId.uuidString, "runId": runId.uuidString,
            "kind": "completed",
        ]
        let expected = ChatNotificationRoute.schedule(sessionId: origin.id, scheduleId: scheduleId, runId: runId)
        precondition(ChatNotificationDelegate.presentationOptions(for: payload) == [.banner, .list, .sound])
        precondition(ChatNotificationDelegate.presentationOptions(for: ["sessionId": origin.id.uuidString]).isEmpty)
        let delegate = ChatNotificationDelegate()
        delegate.receive(userInfo: payload)
        precondition(delegate.consumePending() == expected, "Cold launch must retain the schedule route")
        precondition(delegate.consumePending() == nil, "Cold route must be consumed once")
        let capture = NotificationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: .notificationOpenSession, object: nil, queue: nil
        ) { note in
            capture.route = note.object as? ChatNotificationRoute
        }
        delegate.receive(userInfo: payload)
        precondition(capture.route == expected, "In-app delivery must be typed as a schedule, not origin completion")
        precondition(delegate.consumePending() == expected)
        NotificationCenter.default.removeObserver(observer)
        delegate.receive(userInfo: ["sessionId": origin.id.uuidString])
        precondition(
            delegate.consumePending() == .session(origin.id), "Existing chat notifications must still open their task")
        for invalid: [AnyHashable: Any] in [
            [:], ["sessionId": "invalid"],
            ["sessionId": origin.id.uuidString, "scheduleId": scheduleId.uuidString],
            ["sessionId": origin.id.uuidString, "runId": runId.uuidString],
            ["sessionId": origin.id.uuidString, "scheduleId": "../invalid", "runId": runId.uuidString],
            ["sessionId": origin.id.uuidString, "scheduleId": scheduleId.uuidString, "runId": 42],
        ] {
            precondition(ChatNotificationRoute(userInfo: invalid) == nil)
            precondition(ChatNotificationDelegate.presentationOptions(for: invalid).isEmpty)
            delegate.receive(userInfo: invalid)
            precondition(delegate.consumePending() == nil)
        }
        delegate.receive(userInfo: payload)
        delegate.receive(userInfo: ["sessionId": "invalid"])
        precondition(delegate.consumePending() == expected, "Invalid notifications cannot erase a valid pending route")
        let target = WindowsScheduleNotification(route: expected, sessions: [unrelated, origin])!
        precondition(target.session === origin && target.scheduleId == scheduleId && target.runId == runId)
        precondition(
            WindowsScheduleNotification(route: expected, sessions: [unrelated]) == nil,
            "Missing saved origin must not create a guessed task")
        precondition(WindowsScheduleNotification(route: .session(origin.id), sessions: [origin]) == nil)
        origin.endpoint!.revision = UUID()
        precondition(
            target.connectionKey != origin.connectionKey, "A presented route must retain its original connection scope")
        origin.endpoint!.capabilities = nil
        precondition(WindowsScheduleNotification(route: expected, sessions: [origin]) == nil)
        origin.endpoint!.capabilities = ["agentSchedules"]
        origin.provider = .claude
        precondition(WindowsScheduleNotification(route: expected, sessions: [origin]) == nil)
        origin.provider = .codex
        origin.endpoint = nil
        precondition(WindowsScheduleNotification(route: expected, sessions: [origin]) == nil)
        print(
            "Schedule notification tests passed: cold/in-app routes, schedule-only foreground presentation, strict UUIDs, missing origin and connection fencing"
        )
    }
}
