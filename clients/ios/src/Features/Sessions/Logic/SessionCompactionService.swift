import Foundation
import SwiftData

@MainActor enum SessionCompactionService {
    static func refresh(session: Session, store: SessionCompactionStore, context: ModelContext) async {
        if let endpoint = session.endpoint, let generation = store.begin(session: session, starting: false) {
            let seq = session.lastSeq
            let response = await HTTPClient.get(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/compact", timeout: 15)
            apply(
                response, session: session, endpointId: endpoint.id, seq: seq, store: store, generation: generation,
                context: context)
        }
    }

    static func start(session: Session, store: SessionCompactionStore, context: ModelContext) async {
        if store.canStart(session: session), let endpoint = session.endpoint,
            let generation = store.begin(session: session, starting: true)
        {
            let seq = session.lastSeq
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/compact", body: [:], timeout: 30)
            apply(
                response, session: session, endpointId: endpoint.id, seq: seq, store: store, generation: generation,
                context: context)
            if response == nil && store.generation == generation {
                store.uncertainStart = true
                await refresh(session: session, store: store, context: context)
            }
        }
    }

    static func poll(session: Session, store: SessionCompactionStore, context: ModelContext) async {
        while store.isPending && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && store.isPending { await refresh(session: session, store: store, context: context) }
        }
    }

    static func apply(
        _ response: (Data, HTTPURLResponse)?, session: Session, endpointId: UUID, seq: Int,
        store: SessionCompactionStore, generation: UUID, context: ModelContext
    ) {
        if store.generation == generation {
            if !Task.isCancelled && session.endpoint?.id == endpointId {
                if let (data, http) = response, [200, 202].contains(http.statusCode),
                    let snapshot = try? JSONDecoder().decode(SessionCompactionSnapshot.self, from: data),
                    ["idle", "pending", "completed", "failed"].contains(snapshot.status),
                    snapshot.threadId == nil || session.codexThreadId == nil
                        || snapshot.threadId == session.codexThreadId
                {
                    store.snapshot = snapshot
                    store.error = snapshot.error
                    store.uncertainStart = false
                    if snapshot.status == "completed", session.lastSeq == seq,
                        !session.isStreaming && !session.remoteIsRunning
                    {
                        SessionActions.setContextUsage(
                            tokens: snapshot.contextTokens.flatMap { $0 >= 0 ? $0 : nil },
                            window: snapshot.contextWindow.flatMap { $0 > 0 ? $0 : nil }, for: session.id,
                            context: context)
                    }
                } else {
                    store.error =
                        response.flatMap { try? JSONSerialization.jsonObject(with: $0.0) as? [String: Any] }?["error"]
                        as? String
                        ?? "Could not check context compaction. Refresh its status before trying again."
                }
            }
            store.isLoading = false
            store.isStarting = false
        }
    }
}
