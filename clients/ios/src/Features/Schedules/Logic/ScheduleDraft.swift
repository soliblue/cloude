import Foundation

struct ScheduleDraft {
    var name: String
    var enabled: Bool
    var path: String
    var prompt: String
    var model: String
    var effort: String
    var permissionMode: String
    var kind: String
    var hour: Int
    var minute: Int
    var timeZone: String
    var days: Set<Int>
    var minutes: Int
    var requestId = UUID()
    let scheduleId: String?
    let revision: Int?
    let originSessionId: String
    let connectionKey: String

    init(session: Session, existing: Schedule? = nil) {
        name = existing?.name ?? ""
        enabled = existing?.enabled ?? false
        path = existing?.task.path ?? session.path ?? ""
        prompt = existing?.task.prompt ?? ""
        model = existing?.task.model ?? session.modelRaw ?? ""
        effort = existing?.task.effort ?? session.effortRaw ?? ""
        permissionMode = existing?.task.permissionMode ?? (session.permissionMode == .plan ? "plan" : "default")
        kind = existing?.schedule.kind ?? "calendar"
        hour = Int(existing?.schedule.time?.split(separator: ":").first ?? "09") ?? 9
        minute = Int(existing?.schedule.time?.split(separator: ":").last ?? "00") ?? 0
        timeZone = existing?.schedule.timeZone ?? TimeZone.current.identifier
        days = Set(existing?.schedule.daysOfWeek ?? Array(1...7))
        minutes = existing?.schedule.minutes ?? 60
        scheduleId = existing?.id
        revision = existing?.revision
        originSessionId = existing?.originSessionId ?? session.id.uuidString
        connectionKey = session.connectionKey
    }

    var clockTime: Date {
        get { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now }
        set {
            hour = Calendar.current.component(.hour, from: newValue)
            minute = Calendar.current.component(.minute, from: newValue)
        }
    }

    var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.utf16.count > 120 || name.contains("\0")
        {
            return "Enter a name of 1 to 120 characters."
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.utf16.count > 32768
            || prompt.contains("\0")
        {
            return "Enter an instruction of 1 to 32,768 characters."
        }
        if !path.hasPrefix("/") || path.contains("\0") || path.utf16.count > 4096 {
            return "Choose an absolute project folder on this machine."
        }
        if !["default", "plan"].contains(permissionMode) { return "Choose Default or Plan permissions." }
        if model.utf16.count > 128 || effort.utf16.count > 64 || model.contains("\0") || effort.contains("\0") {
            return "Choose a valid model and reasoning level."
        }
        if kind == "calendar" {
            if TimeZone(identifier: timeZone) == nil { return "Enter a valid time zone, such as Europe/Berlin." }
            if days.isEmpty || !days.isSubset(of: Set(1...7)) { return "Choose at least one day." }
            if !(0...23).contains(hour) || !(0...59).contains(minute) { return "Choose a valid time." }
        } else if kind != "interval" || !(15...10080).contains(minutes) {
            return "Choose an interval from 15 minutes to one week."
        }
        return nil
    }

    var body: [String: Any] {
        var task: [String: Any] = [
            "provider": "codex", "path": path, "prompt": prompt, "permissionMode": permissionMode,
        ]
        if !model.isEmpty { task["model"] = model }
        if !effort.isEmpty { task["effort"] = effort }
        var result: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines), "enabled": enabled,
            "originSessionId": originSessionId, "task": task,
            "schedule": kind == "interval"
                ? ["kind": "interval", "minutes": minutes]
                : [
                    "kind": "calendar", "time": String(format: "%02d:%02d", hour, minute), "timeZone": timeZone,
                    "daysOfWeek": days.sorted(),
                ],
        ]
        if let revision { result["revision"] = revision } else { result["requestId"] = requestId.uuidString }
        return result
    }
}
