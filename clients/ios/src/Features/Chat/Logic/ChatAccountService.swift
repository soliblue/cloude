import Foundation

@MainActor enum ChatAccountService {
    static func invalidate(endpointId: UUID) {
        ChatAccountStore.shared.generations.removeValue(forKey: endpointId)
        ChatAccountStore.shared.accounts.removeValue(forKey: endpointId)
        ChatAccountStore.shared.loading.remove(endpointId)
        ChatAccountStore.shared.errors.removeValue(forKey: endpointId)
    }

    static func refresh(endpoint: Endpoint) async {
        let generation = UUID()
        ChatAccountStore.shared.generations[endpoint.id] = generation
        ChatAccountStore.shared.loading.insert(endpoint.id)
        ChatAccountStore.shared.errors.removeValue(forKey: endpoint.id)
        async let accountRequest = HTTPClient.get(endpoint: endpoint, path: "/codex/account", timeout: 15)
        async let limitsRequest = HTTPClient.get(endpoint: endpoint, path: "/codex/limits", timeout: 15)
        let (accountResponse, limitsResponse) = await (accountRequest, limitsRequest)
        if ChatAccountStore.shared.generations[endpoint.id] == generation {
            if let (data, response) = accountResponse, !Task.isCancelled, response.statusCode == 200,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                let account = object["account"] as? [String: Any]
                var windows: [ChatUsageWindow] = []
                if let (limitsData, limitsHTTP) = limitsResponse, limitsHTTP.statusCode == 200,
                    let limits = try? JSONSerialization.jsonObject(with: limitsData) as? [String: Any]
                {
                    let buckets =
                        limits["rateLimitsByLimitId"] as? [String: [String: Any]]
                        ?? (limits["rateLimits"] as? [String: Any]).map { ["codex": $0] } ?? [:]
                    for (name, bucket) in buckets.sorted(by: { $0.key < $1.key }) {
                        for key in ["primary", "secondary"] {
                            if let window = bucket[key] as? [String: Any], let used = window["usedPercent"] as? Double {
                                let minutes = window["windowDurationMins"] as? Int
                                let duration =
                                    minutes.map {
                                        $0 >= 1440
                                            ? "\($0 / 1440)-day" : ($0 >= 60 ? "\($0 / 60)-hour" : "\($0)-minute")
                                    }
                                    ?? key.capitalized
                                windows.append(
                                    ChatUsageWindow(
                                        id: name + key,
                                        title: (bucket["limitName"] as? String ?? name.capitalized) + " · " + duration,
                                        usedPercent: used,
                                        resetsAt: (window["resetsAt"] as? Double).map {
                                            Date(timeIntervalSince1970: $0)
                                        }))
                            }
                        }
                    }
                }
                ChatAccountStore.shared.accounts[endpoint.id] = ChatAccountSnapshot(
                    email: account?["email"] as? String, plan: account?["planType"] as? String,
                    isSubscription: account?["type"] as? String == "chatgpt", isSignedIn: account != nil,
                    windows: windows)
            } else if !Task.isCancelled {
                ChatAccountStore.shared.errors[endpoint.id] =
                    "Could not read the Codex account on this machine. Check your connection and daemon version."
            }
            ChatAccountStore.shared.loading.remove(endpoint.id)
        }
    }
}
