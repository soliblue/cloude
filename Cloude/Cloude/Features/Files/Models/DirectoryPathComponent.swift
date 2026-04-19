import Foundation
import CloudeShared

struct DirectoryPathComponent: Identifiable {
    var id: String { path }
    let name: String
    let path: String
}

extension String {
    var directoryPathComponents: [DirectoryPathComponent] {
        var components: [DirectoryPathComponent] = []
        var path = self

        while path != "/" && !path.isEmpty {
            components.insert(DirectoryPathComponent(name: path.lastPathComponent, path: path), at: 0)
            path = path.deletingLastPathComponent
        }
        components.insert(DirectoryPathComponent(name: "/", path: "/"), at: 0)

        return components
    }
}
