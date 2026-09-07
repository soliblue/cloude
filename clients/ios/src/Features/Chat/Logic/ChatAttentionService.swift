import Foundation
import SwiftData

@MainActor enum ChatAttentionService {
    private static var refreshing = false

    static func observe(context: ModelContext, interval: Duration = .seconds(5)) async {
        while !Task.isCancelled {
            await refresh(context: context)
            try? await Task.sleep(for: interval)
        }
    }

    static func refresh(context: ModelContext) async {
        if !refreshing && !Task.isCancelled {
            refreshing = true
            defer { refreshing = false }
            let sessions =
                (try? context.fetch(
                    FetchDescriptor<Session>(
                        predicate: #Predicate {
                            $0.providerRaw == "codex" && $0.existsOnServer && !$0.isArchived
                        }))) ?? []
            let groups = Array(
                Dictionary(
                    grouping: sessions.filter {
                        $0.endpoint?.capabilities?.contains("codexAttentionBatch") == true
                    }, by: { $0.endpoint!.id }
                ).values)
            for start in stride(from: 0, to: groups.count, by: 3) {
                if Task.isCancelled { break }
                let tasks = groups[start..<min(start + 3, groups.count)].map { group in
                    Task {
                        for offset in stride(from: 0, to: group.count, by: 100) {
                            if Task.isCancelled { break }
                            let batch = Array(group[offset..<min(offset + 100, group.count)])
                            if let endpoint = batch.first?.endpoint {
                                let scopes = Dictionary(
                                    uniqueKeysWithValues: batch.map {
                                        (
                                            $0.id,
                                            (
                                                $0.connectionKey, $0.codexThreadId,
                                                ChatInteractionStore.shared.revisions[$0.id, default: 0],
                                                ChatInteractionStore.shared.agentRevisions[$0.id, default: 0]
                                            )
                                        )
                                    })
                                if let (data, response) = await HTTPClient.post(
                                    endpoint: endpoint, path: "/codex/attention",
                                    body: ["sessionIds": batch.map { $0.id.uuidString }], timeout: 10),
                                    response.statusCode == 200, !Task.isCancelled,
                                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                    let updates = object["sessions"] as? [[String: Any]],
                                    updates.count == batch.count,
                                    Set(
                                        updates.compactMap {
                                            ($0["sessionId"] as? String).flatMap(UUID.init(uuidString:))
                                        }) == Set(batch.map(\.id))
                                {
                                    for update in updates {
                                        if let id = (update["sessionId"] as? String).flatMap(UUID.init(uuidString:)),
                                            let session = batch.first(where: { $0.id == id }), let scope = scopes[id],
                                            session.modelContext === context, !session.isDeleted, !session.isArchived,
                                            session.provider == .codex, session.existsOnServer,
                                            session.connectionKey == scope.0, session.codexThreadId == scope.1,
                                            let threadId = update["threadId"] as? String,
                                            scope.1 == nil || threadId == scope.1,
                                            update["requests"] is [[String: Any]],
                                            update["agentAttention"] is [[String: Any]]
                                        {
                                            ChatInteractionService.apply(
                                                update, session: session, revision: scope.2, agentRevision: scope.3)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                await withTaskCancellationHandler {
                    for task in tasks { await task.value }
                } onCancel: {
                    for task in tasks { task.cancel() }
                }
            }
        }
    }
}
