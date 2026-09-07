import Foundation

@MainActor enum ChatModelService {
    static func invalidate(sessionId: UUID) {
        ChatModelCatalog.shared.generations.removeValue(forKey: sessionId)
        ChatModelCatalog.shared.options.removeValue(forKey: sessionId)
        ChatModelCatalog.shared.loading.remove(sessionId)
        ChatModelCatalog.shared.errors.removeValue(forKey: sessionId)
    }

    static func refresh(session: Session) async {
        if let endpoint = session.endpoint {
            let generation = UUID()
            ChatModelCatalog.shared.generations[session.id] = generation
            ChatModelCatalog.shared.loading.insert(session.id)
            ChatModelCatalog.shared.errors.removeValue(forKey: session.id)
            let result = await HTTPClient.get(endpoint: endpoint, path: "/codex/models", timeout: 15)
            if ChatModelCatalog.shared.generations[session.id] == generation {
                if let (data, response) = result, !Task.isCancelled,
                    response.statusCode == 200,
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let rows = object["data"],
                    let encoded = try? JSONSerialization.data(withJSONObject: rows),
                    let options = try? JSONDecoder().decode([ChatModelOption].self, from: encoded)
                {
                    ChatModelCatalog.shared.options[session.id] = options
                    EndpointActions.setSupportsCodex(true, for: endpoint)
                    if session.providerRaw == nil && !session.existsOnServer {
                        SessionActions.setProvider(.codex, for: session)
                    }
                } else if session.provider == .codex && !Task.isCancelled {
                    ChatModelCatalog.shared.errors[session.id] =
                        "Could not load models. Auto uses the remote Codex default. Check that Codex is installed and signed in."
                }
                ChatModelCatalog.shared.loading.remove(session.id)
            }
        }
    }
}
