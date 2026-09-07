import Foundation
import SwiftData

enum SessionForkService {
    static func fork(
        session: Session, context: ModelContext, store: SessionForkStore
    ) async -> Bool {
        store.isForking = true
        store.error = nil
        defer { store.isForking = false }
        if !Task.isCancelled, let endpoint = session.endpoint, let path = session.path,
            !(session.isStreaming || session.remoteIsRunning)
                || endpoint.capabilities?.contains("codexActiveFork") == true
        {
            let newId = UUID()
            let connectionKey = session.connectionKey
            if let (data, response) = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/fork",
                body: ["newSessionId": newId.uuidString, "path": path], timeout: 30),
                !Task.isCancelled, session.connectionKey == connectionKey,
                !session.isDeleted, !endpoint.isDeleted
            {
                if response.statusCode != 200,
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let error = object["error"] as? String, !error.isEmpty
                {
                    store.error = String(error.prefix(500))
                }
                if response.statusCode == 200,
                    !session.isDeleted, !endpoint.isDeleted,
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let threadId = object["threadId"] as? String, !threadId.isEmpty,
                    threadId != session.codexThreadId,
                    let history = object["thread"] as? [String: Any], history["id"] as? String == threadId,
                    let cwd = history["cwd"] as? String, cwd.hasPrefix("/"), !cwd.hasPrefix("//"),
                    !cwd.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                    let turns = history["turns"] as? [[String: Any]],
                    (history["status"] as? [String: Any])?["type"] as? String != "active",
                    !turns.contains(where: { $0["status"] as? String == "inProgress" })
                {
                    let fork = SessionActions.fork(
                        session, id: newId, path: (cwd as NSString).standardizingPath, context: context,
                        copyHistory: false)
                    SessionActions.setCodexThreadId(threadId, for: fork)
                    let imported = await ChatActions.importHistory(history, session: fork, context: context)
                    if imported, !Task.isCancelled, session.connectionKey == connectionKey,
                        !session.isDeleted, !endpoint.isDeleted
                    {
                        let windows = (try? context.fetch(FetchDescriptor<Window>())) ?? []
                        WindowActions.open(fork, among: windows, context: context)
                        return true
                    }
                    ChatActions.discardHistory(sessionId: fork.id, context: context)
                    context.delete(fork)
                }
            }
        }
        if store.error == nil { store.error = "Check the connection and make sure the last turn has finished." }
        return false
    }
}
