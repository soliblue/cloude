import Foundation
import CloudeShared

extension RunnerManager {
    var onTeammateInboxUpdate: ((String, TeammateStatus?, String?, Date?, String) -> Void)? {
        get { _onTeammateInboxUpdate }
        set { _onTeammateInboxUpdate = newValue }
    }

    func startInboxPolling(conversationId: String, teamName: String) {
        stopInboxPolling(conversationId: conversationId)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollInbox(conversationId: conversationId, teamName: teamName)
            }
        }
        inboxTimers[conversationId] = timer
    }

    func stopInboxPolling(conversationId: String) {
        inboxTimers[conversationId]?.invalidate()
        inboxTimers.removeValue(forKey: conversationId)
    }

    func pollInbox(conversationId: String, teamName: String) {
        let teamsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/teams/\(teamName)/inboxes")
        let leadInbox = teamsDir.appendingPathComponent("team-lead.json")

        guard let data = try? Data(contentsOf: leadInbox),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        let currentCount = messages.count
        let lastCount = activeTeams[conversationId]?.lastInboxState["team-lead"] ?? 0
        guard currentCount > lastCount else { return }
        activeTeams[conversationId]?.lastInboxState["team-lead"] = currentCount

        for i in lastCount..<currentCount {
            let msg = messages[i]
            guard let from = msg["from"] as? String,
                  let text = msg["text"] as? String else { continue }

            let summary = msg["summary"] as? String
            let timestampStr = msg["timestamp"] as? String

            let timestamp: Date
            if let ts = timestampStr {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: ts) ?? Date()
            } else {
                timestamp = Date()
            }

            if text.contains("\"type\":\"idle_notification\"") {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                _onTeammateInboxUpdate?(teammateId, .idle, nil, nil, conversationId)
            } else if text.contains("\"type\":\"shutdown_approved\"") {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                _onTeammateInboxUpdate?(teammateId, .shutdown, nil, nil, conversationId)
            } else {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                let displayText = summary ?? String(text.prefix(100))
                _onTeammateInboxUpdate?(teammateId, .working, displayText, timestamp, conversationId)
            }
        }
    }

    func findTeammateId(named name: String, conversationId: String) -> String {
        if let teammates = activeTeams[conversationId]?.teammates {
            for (id, info) in teammates where info.name == name {
                return id
            }
        }
        return name
    }
}
