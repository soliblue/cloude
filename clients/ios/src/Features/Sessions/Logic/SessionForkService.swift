import Foundation
import SwiftData

enum SessionForkService {
    static func fork(session: Session, context: ModelContext) async -> Bool {
        if let endpoint = session.endpoint, let path = session.path {
            let newId = UUID()
            let connectionKey = session.connectionKey
            if let (data, response) = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/fork",
                body: ["newSessionId": newId.uuidString, "path": path], timeout: 30),
                response.statusCode == 200, session.connectionKey == connectionKey
            {
                let fork = SessionActions.fork(session, id: newId, context: context)
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let threadId = object["threadId"] as? String
                {
                    SessionActions.setCodexThreadId(threadId, for: fork)
                }
                let windows = (try? context.fetch(FetchDescriptor<Window>())) ?? []
                WindowActions.open(fork, among: windows, context: context)
                return true
            }
        }
        return false
    }
}
