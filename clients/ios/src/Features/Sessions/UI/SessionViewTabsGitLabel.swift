import SwiftData
import SwiftUI

struct SessionViewTabsGitLabel: View {
    let session: Session
    let isActive: Bool
    @Environment(\.appAccent) private var appAccent
    @Query private var statuses: [GitStatus]

    init(session: Session, isActive: Bool) {
        self.session = session
        self.isActive = isActive
        let sessionId = session.id
        _statuses = Query(
            filter: #Predicate<GitStatus> { $0.sessionId == sessionId }
        )
    }

    var body: some View {
        let status = statuses.first
        let additions = status?.changes.compactMap(\.additions).reduce(0, +) ?? 0
        let deletions = status?.changes.compactMap(\.deletions).reduce(0, +) ?? 0
        let branch = status?.branch ?? ""
        let hasChanges = additions > 0 || deletions > 0
        HStack(spacing: ThemeTokens.Spacing.xs) {
            if !hasChanges {
                Image(systemName: SessionTab.git.symbol)
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
            }
            if hasChanges {
                if additions > 0 {
                    Text("+\(Self.formatK(additions))")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .monospacedDigit()
                        .foregroundColor(isActive ? appAccent.color : ThemeColor.success)
                }
                if deletions > 0 {
                    Text("-\(Self.formatK(deletions))")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .monospacedDigit()
                        .foregroundColor(isActive ? appAccent.color : ThemeColor.danger)
                }
            } else if !branch.isEmpty {
                Text(Self.middleTruncated(branch, limit: 12))
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    .lineLimit(1)
            }
        }
        .foregroundColor(isActive ? appAccent.color : .secondary)
    }

    static func formatK(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 1_000_000 {
            let k = Double(n) / 1000
            return k < 10 ? String(format: "%.1fk", k) : "\(Int(k))k"
        }
        let m = Double(n) / 1_000_000
        return m < 10 ? String(format: "%.1fm", m) : "\(Int(m))m"
    }

    static func middleTruncated(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        let head = limit / 2
        let tail = limit - head
        return "\(s.prefix(head))…\(s.suffix(tail))"
    }
}
