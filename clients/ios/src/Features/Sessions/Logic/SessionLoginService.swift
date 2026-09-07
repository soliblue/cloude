import Foundation
import SwiftData

@MainActor enum SessionLoginService {
    static func refresh(endpoint: Endpoint, store: SessionLoginStore) async {
        if let generation = store.begin(endpointId: endpoint.id, mutating: false) {
            let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/login", timeout: 15)
            apply(response, generation: generation, store: store)
        }
    }

    static func start(endpoint: Endpoint, store: SessionLoginStore) async {
        if let generation = store.begin(endpointId: endpoint.id, mutating: true) {
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/codex/login", body: ["type": "chatgptDeviceCode"], timeout: 45)
            apply(response, generation: generation, store: store)
        }
    }

    static func cancel(endpoint: Endpoint, store: SessionLoginStore) async {
        if let generation = store.begin(endpointId: endpoint.id, mutating: true) {
            let response = await HTTPClient.delete(endpoint: endpoint, path: "/codex/login", timeout: 15)
            apply(response, generation: generation, store: store)
        }
    }

    static func poll(endpoint: Endpoint, store: SessionLoginStore) async {
        while store.isPending && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && store.isPending { await refresh(endpoint: endpoint, store: store) }
        }
    }

    static func refreshSignedIn(endpoint: Endpoint, context: ModelContext) async {
        await ChatAccountService.refresh(endpoint: endpoint)
        for session in (try? context.fetch(FetchDescriptor<Session>())) ?? []
        where session.endpoint?.id == endpoint.id && session.provider == .codex && !Task.isCancelled {
            await ChatModelService.refresh(session: session)
        }
    }

    static func apply(_ response: (Data, HTTPURLResponse)?, generation: UUID, store: SessionLoginStore) {
        if !Task.isCancelled {
            if let (data, response) = response,
                let snapshot = try? JSONDecoder().decode(SessionLoginSnapshot.self, from: data),
                ["idle", "pending", "completed", "failed", "canceled"].contains(snapshot.status)
            {
                store.finish(
                    generation, snapshot: snapshot,
                    error: response.statusCode == 200 ? nil : snapshot.error ?? "Sign-in could not complete. Try again."
                )
            } else {
                store.finish(
                    generation, snapshot: nil,
                    error: "Could not reach remote sign-in. Check the connection and daemon version, then retry.")
            }
        } else if store.generation == generation {
            store.invalidate()
        }
    }
}
