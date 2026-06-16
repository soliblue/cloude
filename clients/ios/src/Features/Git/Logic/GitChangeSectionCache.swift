import Foundation

final class GitChangeSectionCache {
    private var key: [GitChangeSectionKey] = []
    private var cached = GitChangeSections(changes: [])

    func sections(for changes: [GitChange]) -> GitChangeSections {
        let newKey = changes.map {
            GitChangeSectionKey(path: $0.path, typeRaw: $0.typeRaw, isStaged: $0.isStaged)
        }
        if key == newKey { return cached }
        cached = GitChangeSections(changes: changes)
        key = newKey
        return cached
    }
}
