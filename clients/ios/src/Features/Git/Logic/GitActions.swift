import Foundation
import SwiftData

enum GitActions {
    private static let isoFormatter = ISO8601DateFormatter()

    @MainActor
    static func upsertStatus(
        sessionId: UUID, dto: GitStatusDTO, context: ModelContext
    ) {
        let descriptor = FetchDescriptor<GitStatus>(
            predicate: #Predicate<GitStatus> { $0.sessionId == sessionId }
        )
        let status =
            (try? context.fetch(descriptor).first)
            ?? {
                let new = GitStatus(sessionId: sessionId)
                context.insert(new)
                return new
            }()
        if status.branch != dto.branch { status.branch = dto.branch }
        if status.ahead != dto.ahead { status.ahead = dto.ahead }
        if status.behind != dto.behind { status.behind = dto.behind }
        status.updatedAt = .now
        let existingKeys = status.changes
            .map { "\($0.path)|\($0.typeRaw)|\($0.isStaged)|\($0.additions ?? -1)|\($0.deletions ?? -1)" }
            .sorted()
        let incomingKeys = dto.changes
            .map { "\($0.path)|\($0.type)|\($0.isStaged)|\($0.additions ?? -1)|\($0.deletions ?? -1)" }
            .sorted()
        let dirty = existingKeys != incomingKeys
        if dirty {
            for change in status.changes { context.delete(change) }
            status.changes.removeAll()
            for wire in dto.changes {
                let type = GitChangeType(rawValue: wire.type) ?? .modified
                let change = GitChange(
                    path: wire.path,
                    type: type,
                    isStaged: wire.isStaged,
                    additions: wire.additions,
                    deletions: wire.deletions
                )
                change.status = status
                context.insert(change)
                status.changes.append(change)
            }
        }
    }

    @MainActor
    static func replaceLog(
        sessionId: UUID, commits: [GitCommitDTO], context: ModelContext
    ) {
        let descriptor = FetchDescriptor<GitCommit>(
            predicate: #Predicate<GitCommit> { $0.sessionId == sessionId }
        )
        if let existing = try? context.fetch(descriptor) {
            for commit in existing { context.delete(commit) }
        }
        for (index, wire) in commits.enumerated() {
            let commit = GitCommit(
                sessionId: sessionId,
                sha: wire.sha,
                subject: wire.subject,
                author: wire.author,
                date: Self.isoFormatter.date(from: wire.date) ?? .now,
                order: index
            )
            context.insert(commit)
        }
    }

    @MainActor
    static func clear(sessionId: UUID, context: ModelContext) {
        let statusDescriptor = FetchDescriptor<GitStatus>(
            predicate: #Predicate<GitStatus> { $0.sessionId == sessionId }
        )
        if let existing = try? context.fetch(statusDescriptor) {
            for status in existing { context.delete(status) }
        }
        let logDescriptor = FetchDescriptor<GitCommit>(
            predicate: #Predicate<GitCommit> { $0.sessionId == sessionId }
        )
        if let existing = try? context.fetch(logDescriptor) {
            for commit in existing { context.delete(commit) }
        }
    }

}
