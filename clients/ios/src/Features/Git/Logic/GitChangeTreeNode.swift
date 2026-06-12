import Foundation

struct GitChangeTreeNode: Identifiable {
    let name: String
    let path: String
    let change: GitChange?
    let children: [GitChangeTreeNode]

    var id: String { path }
    var isFolder: Bool { change == nil }

    static func build(_ changes: [GitChange]) -> [GitChangeTreeNode] {
        nodes(changes.map { ($0.path.split(separator: "/").map(String.init)[...], $0) }, prefix: "")
    }

    private static func nodes(
        _ entries: [(components: ArraySlice<String>, change: GitChange)], prefix: String
    ) -> [GitChangeTreeNode] {
        var files: [GitChangeTreeNode] = []
        var folders: [String: [(components: ArraySlice<String>, change: GitChange)]] = [:]
        for entry in entries {
            if let head = entry.components.first {
                if entry.components.count == 1 {
                    files.append(
                        GitChangeTreeNode(
                            name: head, path: entry.change.path, change: entry.change, children: []))
                } else {
                    folders[head, default: []].append((entry.components.dropFirst(), entry.change))
                }
            }
        }
        let folderNodes = folders.map { name, descendants -> GitChangeTreeNode in
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            let children = nodes(descendants, prefix: path)
            return children.count == 1 && children[0].isFolder
                ? GitChangeTreeNode(
                    name: "\(name)/\(children[0].name)", path: children[0].path, change: nil,
                    children: children[0].children)
                : GitChangeTreeNode(name: name, path: path, change: nil, children: children)
        }
        return folderNodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            + files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
