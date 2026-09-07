import Foundation
import SwiftData

@MainActor enum ChatRemoteControlService {
    static func stop(session: Session, context: ModelContext, store: ChatRemoteControlStore) async {
        if session.provider == .codex, session.followsRemote, session.remoteIsRunning, let endpoint = session.endpoint,
            !store.submitting.contains(session.id)
        {
            let key = session.connectionKey
            store.submitting.insert(session.id)
            store.errors.removeValue(forKey: session.id)
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/chat/abort")
            if session.connectionKey == key {
                if let (_, response) = response, response.statusCode == 200 {
                    store.requested.insert(session.id)
                    await SessionRemoteFollowService.refresh(session: session, context: context)
                    if session.connectionKey == key && !session.remoteIsRunning { store.requested.remove(session.id) }
                } else {
                    store.errors[session.id] = "Could not stop this remote task. Check the connection and try again."
                }
                store.submitting.remove(session.id)
            }
        }
    }
}
