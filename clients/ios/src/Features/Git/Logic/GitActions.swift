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
        sessionId: UUID, commits: [GitCommitDTO], context: ModelContext, append: Bool = false
    ) {
        let descriptor = FetchDescriptor<GitCommit>(
            predicate: #Predicate<GitCommit> { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.order)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let bySHA = Dictionary(existing.map { ($0.sha, $0) }, uniquingKeysWith: { first, _ in first })
        var ordered: [GitCommit] = append ? existing : []
        var seen = Set(ordered.map(\.sha))
        let incoming = Set(commits.map(\.sha))
        for wire in commits where seen.insert(wire.sha).inserted {
            if let commit = bySHA[wire.sha] {
                ordered.append(commit)
            } else {
                let commit = GitCommit(
                    sessionId: sessionId, sha: wire.sha, subject: wire.subject, author: wire.author,
                    date: Self.isoFormatter.date(from: wire.date) ?? .now, order: ordered.count)
                context.insert(commit)
                ordered.append(commit)
            }
        }
        if !append, commits.count >= 50,
            let last = commits.last, let overlap = existing.firstIndex(where: { $0.sha == last.sha })
        {
            ordered.append(contentsOf: existing.suffix(from: overlap + 1).filter { !incoming.contains($0.sha) })
        }
        let retained = Set(ordered.map(\.sha))
        for commit in existing where !retained.contains(commit.sha) { context.delete(commit) }
        for (index, commit) in ordered.enumerated() {
            if commit.order != index { commit.order = index }
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
