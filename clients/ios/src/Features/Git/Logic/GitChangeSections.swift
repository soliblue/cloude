import Foundation

struct GitChangeSections {
    let staged: [GitChange]
    let unstaged: [GitChange]
    let stagedTree: [GitChangeTreeNode]
    let unstagedTree: [GitChangeTreeNode]

    init(changes: [GitChange]) {
        let sorted = changes.sorted { $0.path < $1.path }
        staged = sorted.filter(\.isStaged)
        unstaged = sorted.filter { !$0.isStaged }
        stagedTree = GitChangeTreeNode.build(staged)
        unstagedTree = GitChangeTreeNode.build(unstaged)
    }

    var isEmpty: Bool {
        staged.isEmpty && unstaged.isEmpty
    }
}
