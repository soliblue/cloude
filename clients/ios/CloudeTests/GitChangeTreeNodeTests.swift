import XCTest

@testable import Cloude

final class GitChangeTreeNodeTests: XCTestCase {
    func testBuildGroupsFoldersBeforeFilesAndSortsNames() {
        let changes = [
            GitChange(path: "zeta.swift", type: .modified, isStaged: false),
            GitChange(path: "Sources/App.swift", type: .modified, isStaged: false),
            GitChange(path: "Sources/Core/Theme.swift", type: .modified, isStaged: false),
            GitChange(path: "README.md", type: .modified, isStaged: false),
        ]

        let nodes = GitChangeTreeNode.build(changes)

        XCTAssertEqual(nodes.map(\.name), ["Sources", "README.md", "zeta.swift"])
        XCTAssertEqual(nodes[0].children.map(\.name), ["Core", "App.swift"])
    }

    func testBuildCompressesSingleChildFolderChains() {
        let nodes = GitChangeTreeNode.build([
            GitChange(path: "Sources/Core/Theme/Theme.swift", type: .modified, isStaged: false)
        ])

        XCTAssertEqual(nodes.first?.name, "Sources/Core/Theme")
        XCTAssertEqual(nodes.first?.children.first?.name, "Theme.swift")
    }
}
