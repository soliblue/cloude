import Foundation
import Observation

@MainActor
@Observable
final class SessionProjectStore {
    var projects: [SessionProject] = []
    var nextCursor: String?
    var isLoading = false
    var isCached = false
    var error: String?
    var generation = UUID()
    var cacheScope: UUID?
    var selectableProjects: [SessionProject] { projects.filter { !$0.selectableRoots.isEmpty } }

    func apply(_ page: SessionProjectPage, append: Bool = false, cached: Bool = false) {
        var positions: [String: Int] = [:]
        var result = append ? projects : []
        for (index, project) in result.enumerated() { positions[project.id] = index }
        for project in page.data {
            if let index = positions[project.id] {
                result[index] = project
            } else {
                positions[project.id] = result.count
                result.append(project)
            }
        }
        projects = result
        nextCursor = page.nextCursor
        isCached = cached
    }
}
