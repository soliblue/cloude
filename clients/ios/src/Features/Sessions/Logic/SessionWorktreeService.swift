import Foundation
import SwiftData

@MainActor enum SessionWorktreeService {
    static func load(session: Session, store: SessionWorktreeStore) async {
        if let endpoint = session.endpoint, let path = session.path, !store.isCreating {
            let generation = UUID()
            store.generation = generation
            store.isLoading = true
            store.error = nil
            let response = await HTTPClient.get(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/git/branches", query: ["path": path],
                timeout: 15)
            if store.generation == generation {
                if let (data, response) = response, response.statusCode == 200, !Task.isCancelled,
                    let page = try? JSONDecoder().decode(SessionWorktreeBranches.self, from: data)
                {
                    store.apply(page)
                    if store.branches.isEmpty { store.error = "This repository has no committed branches yet." }
                } else if !Task.isCancelled {
                    store.error = "Could not load branches. Check the machine connection and try again."
                }
                store.isLoading = false
            }
        }
    }

    static func create(session: Session, store: SessionWorktreeStore, context: ModelContext) async -> Session? {
        if let created = store.createdSession {
            if (try? context.save()) != nil { return created }
            store.error = "The worktree is ready, but the task could not be saved. Try again."
            return nil
        }
        if let endpoint = session.endpoint, let path = session.path, endpoint.supportsGitWorktrees, store.canCreate {
            store.isCreating = true
            store.error = nil
            let branch = store.branchName
            let revision = endpoint.connectionRevision
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/git/worktrees",
                body: [
                    "path": path, "branch": branch, "baseRef": store.baseRef,
                    "requestId": store.prepareRequest(path: path).uuidString,
                ], timeout: 60)
            if let (data, response) = response, response.statusCode == 200,
                let result = try? JSONDecoder().decode(SessionWorktreeResult.self, from: data),
                result.path.hasPrefix("/"), !result.path.contains("\0"), result.branch == branch,
                session.endpoint?.id == endpoint.id, endpoint.connectionRevision == revision, session.path == path
            {
                store.createdSession = SessionActions.addWorktree(from: session, result: result, context: context)
                if (try? context.save()) == nil {
                    store.error = "The worktree is ready, but the task could not be saved. Try again."
                }
            } else {
                store.error =
                    response.flatMap { try? JSONSerialization.jsonObject(with: $0.0) as? [String: Any] }?["error"]
                    as? String
                    ?? "Could not create the worktree. Check the machine connection and try again."
            }
            store.isCreating = false
        }
        return store.error == nil ? store.createdSession : nil
    }
}
