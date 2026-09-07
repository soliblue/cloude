import Foundation

@MainActor enum ChatInteractionService {
    static func observe(session: Session, interval: Duration = .seconds(3)) async {
        let connectionKey = session.connectionKey
        await refresh(session: session)
        while (session.followsRemote || !(ChatInteractionStore.shared.agentRequests[session.id] ?? []).isEmpty)
            && session.connectionKey == connectionKey && !Task.isCancelled
        {
            try? await Task.sleep(for: interval)
            if (session.followsRemote || !(ChatInteractionStore.shared.agentRequests[session.id] ?? []).isEmpty)
                && session.connectionKey == connectionKey && !Task.isCancelled
            {
                await refresh(session: session)
            }
        }
    }

    static func refresh(session: Session) async {
        let connectionKey = session.connectionKey
        let revision = ChatInteractionStore.shared.revisions[session.id, default: 0]
        let agentRevision = ChatInteractionStore.shared.agentRevisions[session.id, default: 0]
        if session.provider == .codex, session.existsOnServer, let endpoint = session.endpoint,
            let (data, response) = await HTTPClient.get(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/chat/requests"),
            response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let requests = object["requests"] as? [[String: Any]], !Task.isCancelled,
            session.connectionKey == connectionKey
        {
            let pending = requests.compactMap { request -> ChatInteraction? in
                if let id = request["requestId"] as? String, let method = request["method"] as? String {
                    return ChatInteraction(
                        id: id, method: method, paramsJSON: ChatToolCall.prettyJSON(request["params"] ?? [:]))
                }
                return nil
            }
            _ = ChatInteractionStore.shared.replace(pending, sessionId: session.id, revision: revision)
            if let children = object["agentAttention"] as? [[String: Any]] {
                let notices = children.compactMap { item -> ChatAgentAttention? in
                    if let threadId = item["threadId"] as? String, let requestId = item["requestId"] as? String,
                        !threadId.isEmpty && !requestId.isEmpty
                    {
                        return ChatAgentAttention(threadId: threadId, requestId: requestId)
                    }
                    return nil
                }
                _ = ChatInteractionStore.shared.replaceAgents(notices, sessionId: session.id, revision: agentRevision)
            }
            let hasAttention = ChatInteractionStore.shared.hasAttention(sessionId: session.id)
            if session.needsAttention != hasAttention { SessionActions.setNeedsAttention(hasAttention, for: session) }
        }
    }

    static func respond(session: Session, request: ChatInteraction, result: [String: Any]) async {
        if let endpoint = session.endpoint, !ChatInteractionStore.shared.submitting.contains(request.id) {
            let connectionKey = session.connectionKey
            ChatInteractionStore.shared.submitting.insert(request.id)
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/chat/respond",
                body: ["requestId": request.id, "result": result])
            if session.connectionKey != connectionKey {
                ChatInteractionStore.shared.submitting.remove(request.id)
                return
            }
            if let (_, http) = response, http.statusCode == 200 {
                ChatInteractionStore.shared.remove(request.id, sessionId: session.id)
                SessionActions.setNeedsAttention(
                    ChatInteractionStore.shared.hasAttention(sessionId: session.id), for: session)
            } else {
                ChatInteractionStore.shared.errors[request.id] =
                    "Could not send your response. Reconnect and try again."
            }
            ChatInteractionStore.shared.submitting.remove(request.id)
        }
    }
}
