import Foundation
import Combine
import CloudeShared

final class MemoriesStore: ObservableObject {
    @Published var isPresented = false
    @Published var sections: [MemorySection] = []
    @Published var isLoading = false
    @Published var fromCache = false

    func open(connection: ConnectionManager) {
        AppLogger.beginInterval("memories.open")
        if let cached = MemoriesCache.load() {
            sections = cached.sections
            fromCache = true
            isLoading = connection.isAuthenticated
        } else {
            sections = []
            fromCache = false
            isLoading = true
        }
        if connection.isAuthenticated {
            connection.send(.getMemories)
        }
        isPresented = true
    }

    func handle(sections: [MemorySection]) {
        AppLogger.endInterval("memories.open", details: "sections=\(sections.count)")
        self.sections = sections
        fromCache = false
        isLoading = false
        MemoriesCache.save(sections)
    }
}
